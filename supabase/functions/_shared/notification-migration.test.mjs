import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migration = readFileSync(
  new URL('../../migrations/2026-09-15_fcm_notifications.sql', import.meta.url),
  'utf8',
);
const ingest = readFileSync(
  new URL('../notification-ingest/index.ts', import.meta.url),
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
