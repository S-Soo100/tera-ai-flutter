const notificationTypes = new Set([
  'highlight.ready',
  'device.action.started',
  'device.action.ended',
  'device.action.failed',
  'device.action.skipped',
  'community.comment',
  'community.like_digest',
  'notice.published',
  'maintenance.water_tank',
  'safety.alert',
  'safety.recovered',
  'env.alert.triggered',
]);

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const timezoneIsoPattern = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

function malformed(error) {
  return { ok: false, status: 400, error };
}

function hasText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function hasObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isTimezoneIsoTimestamp(value) {
  if (!hasText(value)) return false;
  const match = value.match(timezoneIsoPattern);
  if (!match) return false;

  const [, yearText, monthText, dayText, hourText, minuteText, secondText, offset] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const hour = Number(hourText);
  const minute = Number(minuteText);
  const second = Number(secondText);
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (
    month < 1 || month > 12 || day < 1 || day > daysInMonth ||
    hour > 23 || minute > 59 || second > 59
  ) {
    return false;
  }
  if (offset !== 'Z') {
    const offsetHour = Number(offset.slice(1, 3));
    const offsetMinute = Number(offset.slice(4, 6));
    if (offsetHour > 14 || offsetMinute > 59 || (offsetHour === 14 && offsetMinute !== 0)) {
      return false;
    }
  }
  return !Number.isNaN(Date.parse(value));
}

function requireText(payload, keys) {
  return keys.every((key) => hasText(payload[key]));
}

// Contract agreed in the 2026-09-16 reply to terra-server (docs/handoffs/
// 2026-09-16-lee-gwanhun-reply-groups-and-push.md §3): only schedule-sourced
// commands are published, `outcome` carries the app verdict, `result` carries
// the raw firmware word (ok/busy/no_ack/...), and `device_id` is the UUID with
// the MQTT client id alongside as `device_key`.
const optionalTextFields = ['result', 'device_key', 'schedule_id', 'enclosure_id', 'device_name', 'error_code'];

function validateDeviceEvent(type, payload) {
  if (!requireText(payload, [
    'command_id',
    'device_id',
    'execution_source',
    'execution_phase',
    'action',
    'outcome',
  ])) {
    return 'device action payload is incomplete';
  }

  if (payload.execution_source !== 'schedule') {
    return 'device action execution_source must be schedule';
  }

  const expected = {
    'device.action.started': ['started', 'succeeded'],
    'device.action.ended': ['ended', 'succeeded'],
    'device.action.failed': ['failed', 'failed'],
    // 가드 스킵(source='guard'): 2026-09-16 결정 답신 §4. guard 객체는 선택.
    'device.action.skipped': ['skipped', 'skipped'],
  }[type];
  if (
    payload.execution_phase !== expected[0] ||
    payload.outcome !== expected[1]
  ) {
    return 'device action type, execution_phase, and outcome must match';
  }
  for (const field of optionalTextFields) {
    if (payload[field] !== undefined && payload[field] !== null && !hasText(payload[field])) {
      return `device action ${field} must be text when present`;
    }
  }
  if (payload.guard !== undefined && payload.guard !== null && !hasObject(payload.guard)) {
    return 'device action guard must be an object when present';
  }
  return null;
}

// v4 온습도 이탈 푸시(terra-server docs/APP_ENV_ALERT_PUSH_2026-11-02.md §2).
// level은 caution/danger다(alerts.severity의 warning/critical이 아님). value·
// threshold는 앱 문구에 쓰지 않으므로 검사하지 않는다 — 제목은 payload.title.
const envAlertKinds = new Set(['env_temp_high', 'env_temp_low', 'env_humid_low', 'env_humid_high']);
const envAlertLevels = new Set(['caution', 'danger']);
const envAlertPhases = new Set(['started', 'reminder']);
const envAlertOptionalTextFields = ['device_key', 'device_name', 'enclosure_id'];

function validateEnvAlertEvent(payload) {
  if (!requireText(payload, ['alert_id', 'device_id', 'kind', 'level', 'phase', 'title'])) {
    return 'env alert payload is incomplete';
  }
  if (!envAlertKinds.has(payload.kind)) return 'env alert kind is unsupported';
  if (!envAlertLevels.has(payload.level)) return 'env alert level must be caution or danger';
  if (!envAlertPhases.has(payload.phase)) return 'env alert phase must be started or reminder';
  // 빈 문자열은 통과시킨다 — 이름 없는 사육장 때문에 푸시가 400으로 버려지면
  // 안 된다. 트리거가 빈 device_name을 '사육장'으로 채운다.
  for (const field of envAlertOptionalTextFields) {
    if (payload[field] !== undefined && payload[field] !== null && typeof payload[field] !== 'string') {
      return `env alert ${field} must be a string when present`;
    }
  }
  return null;
}

function validatePayload(type, payload) {
  if (type.startsWith('device.action.')) {
    return validateDeviceEvent(type, payload);
  }
  if (type === 'highlight.ready') {
    if (!requireText(payload, ['highlight_batch_id'])) {
      return 'highlight payload requires highlight_batch_id';
    }
    return isTimezoneIsoTimestamp(payload.scheduled_for)
      ? null
      : 'highlight payload requires timezone-valid scheduled_for';
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
  if (type === 'env.alert.triggered') {
    return validateEnvAlertEvent(payload);
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
    !isTimezoneIsoTimestamp(value.occurred_at)
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
