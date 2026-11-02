import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migration = readFileSync(
  new URL('../../migrations/20260915000000_fcm_notifications.sql', import.meta.url),
  'utf8',
);
const deviceCopyMigration = readFileSync(
  new URL('../../migrations/20260916000000_notification_device_action_copy.sql', import.meta.url),
  'utf8',
);
const ingest = readFileSync(
  new URL('../notification-ingest/index.ts', import.meta.url),
  'utf8',
);
const dispatch = readFileSync(
  new URL('../dispatch-push/index.ts', import.meta.url),
  'utf8',
);

test('like digests wait for their next epoch bucket boundary while pending', () => {
  const likeDigestFunction = migration.match(
    /CREATE OR REPLACE FUNCTION public\.notify_community_like_digest\(\)[\s\S]*?\n\$\$;/,
  )?.[0];
  assert.ok(likeDigestFunction, 'like digest producer must exist');
  assert.match(
    likeDigestFunction,
    /source, source_event_id, user_id, type, occurred_at, scheduled_at, payload/,
  );
  assert.match(
    likeDigestFunction,
    /to_timestamp\(\(v_bucket_epoch \+ 1\) \* 600\)/,
  );
  assert.match(
    likeDigestFunction,
    /o\.status = 'pending'/,
  );
});

test('ingest persists validated highlight scheduled_for as event scheduled_at', () => {
  assert.match(ingest, /scheduled_at: event\.payload\.scheduled_for/);
});

test('publishes only app_notifications to realtime when the publication needs it', () => {
  const publicationBlock = migration.match(
    /DO \$\$[\s\S]*?ALTER PUBLICATION supabase_realtime ADD TABLE public\.app_notifications;[\s\S]*?\$\$;/,
  )?.[0];
  assert.ok(publicationBlock, 'app_notifications must be added to supabase_realtime');
  assert.match(publicationBlock, /FROM pg_publication/);
  assert.match(publicationBlock, /FROM pg_publication_tables/);
  assert.doesNotMatch(
    publicationBlock,
    /push_devices|notification_events|notification_outbox|notification_deliveries/,
  );
});

test('dispatcher claims have stale-lease recovery, fencing, and delivery rows', () => {
  assert.match(migration, /CREATE TABLE public\.notification_deliveries/);
  assert.match(migration, /lock_token\s+UUID/);
  assert.match(migration, /o\.status = 'processing'\s+AND o\.locked_at < now\(\) - interval '10 minutes'/);
  assert.match(migration, /FOR UPDATE SKIP LOCKED/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.claim_notification_deliveries/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.complete_notification_delivery/);
  assert.match(migration, /p_lock_token/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.finalize_notification_outbox/);
  assert.match(migration, /UNIQUE \(outbox_id, push_device_id\)/);
});

test('delivery recovery keeps active processing work unfinished and fences explicit conflicts', () => {
  const finalize = migration.match(
    /CREATE OR REPLACE FUNCTION public\.finalize_notification_outbox\([\s\S]*?\n\$\$;/,
  )?.[0];
  assert.ok(finalize, 'outbox finalizer must exist');
  assert.match(
    migration,
    /ON CONFLICT ON CONSTRAINT notification_deliveries_outbox_id_push_device_id_key DO NOTHING/,
  );
  assert.match(finalize, /d\.status IN \('pending', 'processing'\) AND p\.enabled/);
  assert.match(finalize, /d\.locked_at \+ interval '10 minutes'/);
  assert.match(finalize, /ELSIF v_has_active_failed THEN\s+v_status := 'failed'/);
});

test('dispatcher caps work at one outbox and ten deliveries with abortable database calls', () => {
  assert.match(dispatch, /const deliveryClaimLimit = 10/);
  assert.match(dispatch, /p_limit: 1/);
  assert.match(dispatch, /p_limit: Math\.min\(deliveryClaimLimit, remainingSends\)/);
  assert.match(dispatch, /\.abortSignal\(signal\)/);
  assert.match(dispatch, /return await consume\(response\)/);
});

test('notification security-definer functions revoke every client role before narrow grants', () => {
  const internalFunctions = [
    'notification_event_after_insert()',
    'register_push_device(UUID, TEXT, TEXT, TEXT, TEXT)',
    'deactivate_push_device(UUID)',
    'claim_notification_outbox(INTEGER)',
    'claim_notification_deliveries(UUID, UUID, INTEGER)',
    'get_notification_delivery_token(UUID, UUID, UUID)',
    'complete_notification_delivery(UUID, UUID, TEXT, TIMESTAMPTZ, TEXT)',
    'finalize_notification_outbox(UUID, UUID)',
    'notify_community_comment()',
    'notify_community_like_digest()',
    'notify_community_notice()',
    'schedule_water_tank_notification(TIMESTAMPTZ, UUID, TEXT)',
  ];
  for (const signature of internalFunctions) {
    const escaped = signature.replace(/[()]/g, '\\$&').replace(/ /g, '\\s+');
    assert.match(
      migration,
      new RegExp(`REVOKE EXECUTE ON FUNCTION public\\.${escaped} FROM PUBLIC, anon, authenticated;`),
    );
  }
  assert.doesNotMatch(
    migration,
    /GRANT EXECUTE ON FUNCTION public\.(claim_notification_outbox|claim_notification_deliveries|get_notification_delivery_token|complete_notification_delivery|finalize_notification_outbox)[\s\S]*?TO (?:anon|authenticated|PUBLIC)/,
  );
});

test('delivery claim omits tokens and eligibility checks the current fenced account', () => {
  const claim = migration.match(
    /CREATE OR REPLACE FUNCTION public\.claim_notification_deliveries\([\s\S]*?\n\$\$;/,
  )?.[0];
  const eligibility = migration.match(
    /CREATE OR REPLACE FUNCTION public\.get_notification_delivery_token\([\s\S]*?\n\$\$;/,
  )?.[0];
  assert.ok(claim && eligibility, 'claim and eligibility functions must exist');
  assert.doesNotMatch(claim, /fcm_token/);
  assert.match(eligibility, /p\.enabled = true/);
  assert.match(eligibility, /p\.user_id = o\.user_id/);
  assert.match(eligibility, /d\.lock_token = p_delivery_lock_token/);
});

test('dispatcher bounds queue draining and prioritizes urgent due rows', () => {
  assert.match(dispatch, /const maxOutboxRows = 10/);
  assert.match(dispatch, /const maxFcmSends = 10/);
  assert.match(dispatch, /const invocationBudgetMs = 180_000/);
  assert.match(dispatch, /for\s*\(\s*let outboxCount = 0;\s*outboxCount < maxOutboxRows/);
  assert.match(dispatch, /remainingSends/);
  assert.match(migration, /WHEN n\.kind LIKE 'safety\.%' THEN 0/);
  assert.match(migration, /WHEN n\.kind LIKE 'device\.action\.%' THEN 1/);
});

test('dispatcher charges the global send budget before a send can later throw', () => {
  assert.match(dispatch, /type SendBudget = \{ sends: number \};/);
  assert.match(dispatch, /const budget: SendBudget = \{ sends: 0 \};/);
  assert.match(dispatch, /budget\.sends \+= 1;/);
  assert.doesNotMatch(dispatch, /sends \+= await dispatchRow/);
  assert.ok(
    dispatch.indexOf('budget.sends += 1;') < dispatch.indexOf('await sendFirebaseMessage'),
    'a send attempt must consume budget before subsequent RPC/finalize failures',
  );
});

test('device action copy migration keeps the trigger function name and distinguishes no-ack failures', () => {
  assert.match(deviceCopyMigration, /CREATE OR REPLACE FUNCTION public\.notification_event_after_insert\(\)/);
  assert.doesNotMatch(deviceCopyMigration, /CREATE TRIGGER/);
  assert.match(deviceCopyMigration, /NEW\.payload ->> 'device_name'/);
  assert.match(deviceCopyMigration, /v_result IN \('no_ack', 'expired', 'lost', 'sent', 'unknown_device'\)/);
  assert.match(deviceCopyMigration, /WHEN 'led_on' THEN 'LED 켜기'/);
  // 다른 type 문구는 원본과 동일해야 한다 — 하이라이트 한 줄로 대표 확인.
  assert.match(deviceCopyMigration, /v_route := '\/crecam\/highlights'/);
});

test('device action copy migration admits the guard-skipped type and its copy', () => {
  assert.match(deviceCopyMigration, /DROP CONSTRAINT IF EXISTS notification_events_type_check/);
  assert.match(deviceCopyMigration, /'device\.action\.skipped',\s+'community\.comment'/);
  assert.match(deviceCopyMigration, /WHEN 'device\.action\.skipped' THEN/);
});

// ── v4 온습도 이탈 푸시(env.alert.triggered, 2026-11-02 Task 8) ──────────────────
const envAlertMigration = readFileSync(
  new URL('../../migrations/20261102000100_notification_env_alert.sql', import.meta.url),
  'utf8',
);
const deviceOfflineMigration = readFileSync(
  new URL('../../migrations/20261001000000_notification_device_offline_copy.sql', import.meta.url),
  'utf8',
);

function functionBlock(sql, name) {
  return sql.match(
    new RegExp(`CREATE OR REPLACE FUNCTION public\\.${name}\\([\\s\\S]*?\\n\\$\\$;`),
  )?.[0];
}

function typeCheckList(sql) {
  const block = sql.match(
    /ADD CONSTRAINT notification_events_type_check CHECK \(type IN \(([\s\S]*?)\)\);/,
  )?.[1];
  return block ? [...block.matchAll(/'([^']+)'/g)].map((m) => m[1]) : [];
}

// 이전 정의의 줄이 모두 같은 순서로 남아 있어야 한다(분기·문구 유실 방지).
function assertKeepsEveryLine(previous, next, label) {
  const nextLines = next.split('\n').map((line) => line.trim());
  let cursor = 0;
  for (const line of previous.split('\n').map((l) => l.trim()).filter(Boolean)) {
    const found = nextLines.indexOf(line, cursor);
    assert.ok(found >= 0, `${label}: 이전 정의의 줄이 빠졌거나 순서가 바뀜 — ${line}`);
    cursor = found + 1;
  }
}

test('env alert migration keeps every existing type and admits env.alert.triggered', () => {
  const previous = typeCheckList(deviceCopyMigration);
  const next = typeCheckList(envAlertMigration);
  assert.equal(previous.length, 11, '기준 타입 목록(20260916)을 읽지 못함');
  assert.match(envAlertMigration, /DROP CONSTRAINT IF EXISTS notification_events_type_check/);
  for (const type of previous) assert.ok(next.includes(type), `타입 유실: ${type}`);
  assert.ok(next.includes('env.alert.triggered'));
  assert.equal(next.length, previous.length + 1);
});

test('env alert trigger copies the 2026-10-01 body and adds only the env branch', () => {
  const previous = functionBlock(deviceOfflineMigration, 'notification_event_after_insert');
  const next = functionBlock(envAlertMigration, 'notification_event_after_insert');
  assert.ok(previous && next, 'trigger function must exist in both migrations');
  assert.doesNotMatch(envAlertMigration, /CREATE TRIGGER/);
  // outbox INSERT는 수신 끔 IF 안으로 들여 쓰므로 줄 단위 비교에서 그 부분만 뺀다.
  const [previousHead] = previous.split('  IF v_notification_id IS NOT NULL THEN');
  assertKeepsEveryLine(previousHead, next, 'notification_event_after_insert');
  for (const type of typeCheckList(deviceCopyMigration)) {
    assert.match(next, new RegExp(`WHEN '${type.replace(/\./g, '\\.')}' THEN`), `분기 유실: ${type}`);
  }
  const envBranch = next.match(/WHEN 'env\.alert\.triggered' THEN([\s\S]*?)\n\s*END CASE;/)?.[1];
  assert.ok(envBranch, 'env 분기는 CASE의 마지막 WHEN이어야 한다');
  assert.match(envBranch, /v_title := NEW\.payload ->> 'title';/);
  assert.match(envBranch, /v_body := COALESCE\(NULLIF\(NEW\.payload ->> 'device_name', ''\), '사육장'\);/);
  assert.match(envBranch, /v_route := '\/env-detail';/);
});

test('env alert trigger skips only the outbox when the account turned the topic off', () => {
  const next = functionBlock(envAlertMigration, 'notification_event_after_insert');
  const appInsert = next.indexOf('INSERT INTO public.app_notifications');
  const preference = next.indexOf('FROM public.notification_preferences');
  const outboxInsert = next.indexOf('INSERT INTO public.notification_outbox');
  assert.ok(appInsert >= 0 && preference > appInsert && outboxInsert > preference,
    '기록(app_notifications) → 수신 설정 확인 → outbox 순서여야 한다');
  assert.match(next, /COALESCE\(\(\s*SELECT p\.env_temp\s+FROM public\.notification_preferences AS p\s+WHERE p\.user_id = NEW\.user_id\s*\), true\)/);
  assert.match(next, /COALESCE\(\(\s*SELECT p\.env_humid\s+FROM public\.notification_preferences AS p\s+WHERE p\.user_id = NEW\.user_id\s*\), true\)/);
  assert.match(next, /NEW\.payload ->> 'kind' LIKE 'env\\_temp\\_%'/);
  assert.match(next, /NEW\.payload ->> 'kind' LIKE 'env\\_humid\\_%'/);
  assert.match(next, /IF v_notification_id IS NOT NULL AND v_push_enabled THEN/);
});

test('env alert claim keeps the original ordering and ranks env alerts with safety', () => {
  const previous = functionBlock(migration, 'claim_notification_outbox');
  const next = functionBlock(envAlertMigration, 'claim_notification_outbox');
  assert.ok(previous && next, 'claim function must exist in both migrations');
  assertKeepsEveryLine(previous, next, 'claim_notification_outbox');
  assert.match(next, /WHEN n\.kind LIKE 'safety\.%' THEN 0\s+WHEN n\.kind = 'env\.alert\.triggered' THEN 0\s+WHEN n\.kind LIKE 'device\.action\.%' THEN 1/);
});
