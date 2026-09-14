import test from 'node:test';
import assert from 'node:assert/strict';
import { buildFirebaseMessage, classifyFcmFailure } from './firebase-message.mjs';

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

test('classifies unregistered token as terminal', () => {
  assert.equal(classifyFcmFailure(404, 'UNREGISTERED'), 'disable-token');
});
