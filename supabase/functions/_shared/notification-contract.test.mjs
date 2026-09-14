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
    result: 'succeeded',
  },
};

test('accepts a matching scheduled action event', () => {
  assert.equal(validateNotificationEvent(validDeviceEvent).ok, true);
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
