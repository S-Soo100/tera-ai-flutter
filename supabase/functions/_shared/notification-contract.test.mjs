import test from 'node:test';
import assert from 'node:assert/strict';
import { validateNotificationEvent } from './notification-contract.mjs';

const validDeviceEvent = {
  schema_version: 1,
  event_id: 'command:c1:started',
  type: 'device.action.started',
  occurred_at: '2026-09-15T21:00:03+09:00',
  user_id: '4da7f48b-0000-4000-8000-111111111111',
  payload: {
    command_id: 'c1',
    device_id: 'd1',
    execution_source: 'schedule',
    execution_phase: 'started',
    action: 'fan_on',
    outcome: 'succeeded',
    result: 'ok',
    device_key: 'terra-1a2b3c4d',
  },
};

test('accepts a matching scheduled action event', () => {
  assert.equal(validateNotificationEvent(validDeviceEvent).ok, true);
});

test('accepts failed events carrying the raw firmware result and no-ack expiry', () => {
  for (const result of ['busy', 'no_ack', 'expired', undefined]) {
    const event = {
      ...validDeviceEvent,
      event_id: 'command:c1:failed',
      type: 'device.action.failed',
      payload: {
        ...validDeviceEvent.payload,
        execution_phase: 'failed',
        outcome: 'failed',
        result,
      },
    };
    assert.equal(validateNotificationEvent(event).ok, true, String(result));
  }
});

test('rejects the legacy result-only verdict, the timer source, and non-text optionals', () => {
  const { outcome: _outcome, ...legacyPayload } = { ...validDeviceEvent.payload, result: 'succeeded' };
  assert.equal(validateNotificationEvent({ ...validDeviceEvent, payload: legacyPayload }).status, 400);
  assert.equal(validateNotificationEvent({
    ...validDeviceEvent,
    payload: { ...validDeviceEvent.payload, execution_source: 'timer' },
  }).status, 400);
  assert.equal(validateNotificationEvent({
    ...validDeviceEvent,
    payload: { ...validDeviceEvent.payload, device_key: 42 },
  }).status, 400);
});

test('rejects a mismatched phase and unsupported source', () => {
  const result = validateNotificationEvent({
    ...validDeviceEvent,
    event_id: 'command:c1:ended',
    type: 'device.action.ended',
    payload: {
      ...validDeviceEvent.payload,
      execution_source: 'manual',
      execution_phase: 'started',
      action: 'fan_off',
    },
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
});

test('rejects an unknown type as unsupported', () => {
  const result = validateNotificationEvent({
    ...validDeviceEvent,
    type: 'device.action.future',
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 422);
});

test('requires a UUID user, timezone-bearing timestamp, event id, and object payload', () => {
  for (const invalid of [
    { ...validDeviceEvent, user_id: 'not-a-uuid' },
    { ...validDeviceEvent, occurred_at: '2026-09-15T21:00:03' },
    { ...validDeviceEvent, event_id: '  ' },
    { ...validDeviceEvent, payload: [] },
  ]) {
    assert.equal(validateNotificationEvent(invalid).status, 400);
  }
});

test('requires a timezone-valid scheduled_for for highlight events', () => {
  const event = {
    ...validDeviceEvent,
    type: 'highlight.ready',
    payload: {
      highlight_batch_id: 'batch-1',
      scheduled_for: '2026-09-16T08:00:00+09:00',
    },
  };
  assert.equal(validateNotificationEvent(event).ok, true);
  assert.equal(validateNotificationEvent({
    ...event,
    payload: { highlight_batch_id: 'batch-1' },
  }).status, 400);
  assert.equal(validateNotificationEvent({
    ...event,
    payload: { highlight_batch_id: 'batch-1', scheduled_for: '2026-09-16T08:00:00' },
  }).status, 400);
  assert.equal(validateNotificationEvent({
    ...event,
    payload: { highlight_batch_id: 'batch-1', scheduled_for: '2026-02-30T08:00:00Z' },
  }).status, 400);
});

test('rejects impossible calendar dates even when Date.parse normalizes them', () => {
  assert.equal(validateNotificationEvent({
    ...validDeviceEvent,
    occurred_at: '2026-02-30T12:00:00Z',
  }).status, 400);
});

test('accepts guard-skipped events with an optional guard object and rejects a non-object guard', () => {
  const skipped = {
    ...validDeviceEvent,
    event_id: 'command:c9:skipped',
    type: 'device.action.skipped',
    payload: {
      ...validDeviceEvent.payload,
      action: 'heater_on',
      execution_phase: 'skipped',
      outcome: 'skipped',
      result: 'guard_skipped',
      guard: { kind: 'temp_above', metric: 'temperature', threshold: 30, value: 33.5 },
    },
  };
  assert.equal(validateNotificationEvent(skipped).ok, true);
  const { guard: _guard, ...withoutGuard } = skipped.payload;
  assert.equal(validateNotificationEvent({ ...skipped, payload: withoutGuard }).ok, true);
  assert.equal(validateNotificationEvent({
    ...skipped,
    payload: { ...skipped.payload, guard: 'temp_above' },
  }).status, 400);
  assert.equal(validateNotificationEvent({
    ...skipped,
    payload: { ...skipped.payload, outcome: 'failed' },
  }).status, 400);
});

// v4 온습도 이탈 푸시(terra-server docs/APP_ENV_ALERT_PUSH_2026-11-02.md §2.1).
// device_key는 비어 있으면 키 자체가 빠진다 — undefined는 키 제거로 다룬다.
function envEvent(overrides = {}) {
  const payload = {
    alert_id: '5ec3b4d1-0000-4000-8000-222222222222',
    device_id: '7a1c0e2f-0000-4000-8000-333333333333',
    device_key: 'terra-1a2b3c4d',
    device_name: '거실 사육장',
    enclosure_id: '9b2d1f3a-0000-4000-8000-444444444444',
    kind: 'env_temp_high',
    level: 'caution',
    phase: 'started',
    title: '[고온 주의] 적정 온도보다 +0.3℃',
    value: 26.3,
    threshold: 26.0,
    ...overrides,
  };
  for (const key of Object.keys(payload)) {
    if (payload[key] === undefined) delete payload[key];
  }
  return {
    schema_version: 1,
    event_id: `alert:${payload.alert_id}:${payload.phase}`,
    type: 'env.alert.triggered',
    occurred_at: '2026-11-02T05:02:03+00:00',
    user_id: '4da7f48b-0000-4000-8000-111111111111',
    payload,
  };
}

test('env alert started 통과', () => assert.equal(validateNotificationEvent(envEvent()).ok, true));
test('env alert reminder 통과', () => assert.equal(validateNotificationEvent(envEvent({ phase: 'reminder' })).ok, true));
test('env alert level 오타 거절', () => assert.equal(validateNotificationEvent(envEvent({ level: 'warning' })).ok, false));
test('env alert title 빈 값 거절', () => assert.equal(validateNotificationEvent(envEvent({ title: '' })).ok, false));
test('device_key 없어도 통과', () => assert.equal(validateNotificationEvent(envEvent({ device_key: undefined })).ok, true));

test('env alert는 kind 4종과 danger 등급을 받는다', () => {
  for (const kind of ['env_temp_high', 'env_temp_low', 'env_humid_low', 'env_humid_high']) {
    assert.equal(validateNotificationEvent(envEvent({ kind, level: 'danger' })).ok, true, kind);
  }
});

test('env alert는 모르는 kind·phase와 필수 id 누락을 400으로 거절한다', () => {
  for (const overrides of [
    { kind: 'temp_high' },
    { kind: 'env_light_low' },
    { phase: 'resolved' },
    { alert_id: undefined },
    { device_id: '  ' },
    { title: undefined },
  ]) {
    assert.equal(validateNotificationEvent(envEvent(overrides)).status, 400, JSON.stringify(overrides));
  }
});

test('env alert 선택 텍스트 필드는 있으면 문자열이어야 한다', () => {
  for (const field of ['device_key', 'device_name', 'enclosure_id']) {
    assert.equal(validateNotificationEvent(envEvent({ [field]: 42 })).status, 400, field);
    assert.equal(validateNotificationEvent(envEvent({ [field]: undefined })).ok, true, field);
    assert.equal(validateNotificationEvent(envEvent({ [field]: '' })).ok, true, field);
    assert.equal(validateNotificationEvent(envEvent({ [field]: null })).ok, true, field);
  }
});
