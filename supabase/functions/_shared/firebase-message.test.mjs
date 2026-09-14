import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildFirebaseMessage,
  classifyFcmFailure,
  extractFcmFailure,
  retryDelaySeconds,
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
