import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migration = readFileSync(
  new URL('../../migrations/20260915000000_fcm_notifications.sql', import.meta.url),
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
  assert.match(dispatch, /const outboxClaimLimit = 1/);
  assert.match(dispatch, /const deliveryClaimLimit = 10/);
  assert.match(dispatch, /p_limit: outboxClaimLimit/);
  assert.match(dispatch, /p_limit: deliveryClaimLimit/);
  assert.match(dispatch, /\.abortSignal\(signal\)/);
  assert.match(dispatch, /return await consume\(response\)/);
});
