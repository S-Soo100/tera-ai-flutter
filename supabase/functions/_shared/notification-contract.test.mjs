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
