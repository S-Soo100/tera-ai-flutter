import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildFirebaseMessage,
  classifyFcmFailure,
  canRetryDelivery,
  extractFcmFailure,
  retryDelaySeconds,
  usesTimeSensitive,
} from './firebase-message.mjs';

test('builds string-only data and safety channel', () => {
  const message = buildFirebaseMessage({
    token: 'token',
    notificationId: 'n1',
    kind: 'safety.alert',
    title: '온도 경고',
    body: '확인해 주세요',
    route: '/env-detail',
  });

  assert.equal(message.message.android.notification.channel_id, 'vivanaut_safety');
  assert.deepEqual(message.message.data, {
    notification_id: 'n1',
    kind: 'safety.alert',
    route: '/env-detail',
  });
});

test('env alert uses the safety channel; other kinds stay on default', () => {
  const channel = (kind) => buildFirebaseMessage({
    token: 'token',
    notificationId: 'n1',
    kind,
    title: '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요',
    body: '거실 사육장',
    route: '/env-detail',
  }).message.android.notification.channel_id;
  assert.equal(channel('env.alert.triggered'), 'vivanaut_safety');
  assert.equal(channel('device.action.failed'), 'vivanaut_default');
  assert.equal(channel('highlight.ready'), 'vivanaut_default');
});

test('classifies typed unregistered token as terminal', () => {
  assert.equal(classifyFcmFailure(404, { fcmErrorCode: 'UNREGISTERED' }), 'disable-token');
});

test('extracts typed FCM errors from Google envelopes', () => {
  assert.deepEqual(extractFcmFailure({
    error: {
      status: 'NOT_FOUND',
      details: [{
        '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
        errorCode: 'UNREGISTERED',
      }],
    },
  }), {
    status: 'NOT_FOUND',
    fcmErrorCode: 'UNREGISTERED',
  });
});

test('disables only a typed token-specific invalid argument', () => {
  const typedInvalidToken = extractFcmFailure({
    error: {
      status: 'INVALID_ARGUMENT',
      details: [{
        '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
        errorCode: 'INVALID_ARGUMENT',
      }],
    },
  });
  assert.equal(classifyFcmFailure(400, typedInvalidToken), 'disable-token');
  assert.equal(
    classifyFcmFailure(400, extractFcmFailure({ error: { status: 'INVALID_ARGUMENT' } })),
    'fail',
  );
});

test('does not disable tokens for generic invalid arguments or malformed envelopes', () => {
  assert.equal(classifyFcmFailure(400, { status: 'INVALID_ARGUMENT' }), 'fail');
  assert.equal(classifyFcmFailure(400, {}), 'fail');
});

test('honors Retry-After and waits at least one minute before the first quota retry', () => {
  assert.equal(retryDelaySeconds(1, 0, 429), 60);
  assert.equal(retryDelaySeconds(1, 120, 503), 120);
});

test('retries through attempt seven and terminates attempt eight', () => {
  assert.equal(canRetryDelivery(7), true);
  assert.equal(canRetryDelivery(8), false);
});

const buildFor = (kind) => buildFirebaseMessage({
  token: 'token',
  notificationId: 'n1',
  kind,
  title: '제목',
  body: '본문',
  route: '/notifications',
});

test('alert kinds get default sound and time-sensitive interruption on iOS', () => {
  for (const kind of ['env.alert.triggered', 'safety.alert']) {
    assert.deepStrictEqual(buildFor(kind).message.apns, {
      payload: { aps: { sound: 'default', 'interruption-level': 'time-sensitive' } },
    }, kind);
  }
});

test('non-alert kinds get default sound only on iOS (no interruption-level key)', () => {
  for (const kind of ['safety.recovered', 'community.comment']) {
    assert.deepStrictEqual(buildFor(kind).message.apns, {
      payload: { aps: { sound: 'default' } },
    }, kind);
  }
});

test('android block is unchanged by the apns block', () => {
  const expected = {
    'env.alert.triggered': 'vivanaut_safety',
    'safety.alert': 'vivanaut_safety',
    'safety.recovered': 'vivanaut_safety',
    'community.comment': 'vivanaut_default',
  };
  for (const [kind, channelId] of Object.entries(expected)) {
    assert.deepStrictEqual(buildFor(kind).message.android, {
      priority: 'high',
      notification: { channel_id: channelId },
    }, kind);
  }
});

test('usesTimeSensitive is true only for active alerts', () => {
  assert.equal(usesTimeSensitive('env.alert.triggered'), true);
  assert.equal(usesTimeSensitive('safety.alert'), true);
  assert.equal(usesTimeSensitive('safety.recovered'), false);
  assert.equal(usesTimeSensitive('community.comment'), false);
  assert.equal(usesTimeSensitive(''), false);
});
