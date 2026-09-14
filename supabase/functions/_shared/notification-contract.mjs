const notificationTypes = new Set([
  'highlight.ready',
  'device.action.started',
  'device.action.ended',
  'device.action.failed',
  'community.comment',
  'community.like_digest',
  'notice.published',
  'maintenance.water_tank',
  'safety.alert',
  'safety.recovered',
]);

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const timezoneIsoPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

function malformed(error) {
  return { ok: false, status: 400, error };
}

function hasText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function hasObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function requireText(payload, keys) {
  return keys.every((key) => hasText(payload[key]));
}

function validateDeviceEvent(type, payload) {
  if (!requireText(payload, [
    'command_id',
    'device_id',
    'execution_source',
    'execution_phase',
    'action',
    'result',
  ])) {
    return 'device action payload is incomplete';
  }

  if (!['schedule', 'timer'].includes(payload.execution_source)) {
    return 'device action execution_source must be schedule or timer';
  }

  const expected = {
    'device.action.started': ['started', 'succeeded'],
    'device.action.ended': ['ended', 'succeeded'],
    'device.action.failed': ['failed', 'failed'],
  }[type];
  if (
    payload.execution_phase !== expected[0] ||
    payload.result !== expected[1]
  ) {
    return 'device action type, execution_phase, and result must match';
  }
  return null;
}

function validatePayload(type, payload) {
  if (type.startsWith('device.action.')) {
    return validateDeviceEvent(type, payload);
  }
  if (type === 'highlight.ready') {
    return requireText(payload, ['highlight_batch_id'])
      ? null
      : 'highlight payload requires highlight_batch_id';
  }
  if (type === 'safety.alert' || type === 'safety.recovered') {
    if (!requireText(payload, ['alert_id', 'device_id', 'metric', 'state'])) {
      return 'safety payload is incomplete';
    }
    const expectedState = type === 'safety.alert' ? 'active' : 'recovered';
    return payload.state === expectedState
      ? null
      : 'safety type and state must match';
  }
  if (type === 'community.comment') {
    return requireText(payload, ['post_id', 'comment_id'])
      ? null
      : 'comment payload is incomplete';
  }
  if (type === 'community.like_digest') {
    return requireText(payload, ['post_id']) && Number.isInteger(payload.like_count) && payload.like_count > 0
      ? null
      : 'like digest payload is incomplete';
  }
  if (type === 'notice.published') {
    return requireText(payload, ['notice_id'])
      ? null
      : 'notice payload requires notice_id';
  }
  if (type === 'maintenance.water_tank') {
    return requireText(payload, ['enclosure_id', 'enclosure_name'])
      ? null
      : 'water tank payload is incomplete';
  }
  return malformed('unsupported notification type');
}

export function validateNotificationEvent(value) {
  if (!hasObject(value)) return malformed('event must be an object');
  if (value.schema_version !== 1) {
    return malformed('schema_version must be 1');
  }
  if (!hasText(value.event_id)) return malformed('event_id is required');
  if (!hasText(value.user_id) || !uuidPattern.test(value.user_id)) {
    return malformed('user_id must be a UUID');
  }
  if (
    !hasText(value.occurred_at) ||
    !timezoneIsoPattern.test(value.occurred_at) ||
    Number.isNaN(Date.parse(value.occurred_at))
  ) {
    return malformed('occurred_at must be a timezone-bearing ISO-8601 timestamp');
  }
  if (!hasObject(value.payload)) return malformed('payload must be an object');
  if (!hasText(value.type) || !notificationTypes.has(value.type)) {
    return { ok: false, status: 422, error: 'unsupported notification type' };
  }

  const payloadError = validatePayload(value.type, value.payload);
  if (payloadError) {
    return malformed(payloadError);
  }
  return { ok: true, value };
}
