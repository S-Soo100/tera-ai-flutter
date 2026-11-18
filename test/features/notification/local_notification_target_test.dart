import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/domain/local_notification_target.dart';

const _uuid = '4da7f48b-0000-4000-8000-111111111111';

void main() {
  test('sched:<uuid> opens the routines of that device', () {
    final target = parseLocalNotificationPayload('sched:$_uuid');
    expect(target,
        const DeviceNotificationTarget(DeviceNotificationKind.schedule, _uuid));
    target as DeviceNotificationTarget;
    expect(target.routeAfterSelect(selected: true), '/home/routines');
    // 내 기기가 아니거나 목록을 못 읽으면 엉뚱한 사육장 예약 대신 홈.
    expect(target.routeAfterSelect(selected: false), '/home');
  });

  test('fan:<uuid> always lands on home', () {
    final target = parseLocalNotificationPayload('fan:${_uuid.toUpperCase()}');
    expect(
        target,
        DeviceNotificationTarget(
            DeviceNotificationKind.fan, _uuid.toUpperCase()));
    target as DeviceNotificationTarget;
    expect(target.routeAfterSelect(selected: true), '/home');
    expect(target.routeAfterSelect(selected: false), '/home');
  });

  test('JSON with a notification id stays on the FCM path', () {
    final target = parseLocalNotificationPayload(
        '{"notification_id":"n1","kind":"env.alert.triggered","route":"/env-detail"}');
    expect(
        target,
        const PushNotificationTarget(
            notificationId: 'n1',
            kind: 'env.alert.triggered',
            route: '/env-detail'));
    // 문자열이 아닌 필드는 빈 값으로 — 기존 _localTap과 같은 규칙.
    expect(
        parseLocalNotificationPayload(
            '{"notification_id":"n2","kind":3,"route":[]}'),
        const PushNotificationTarget(notificationId: 'n2', kind: '', route: ''));
  });

  test('anything else is ignored', () {
    for (final payload in [
      '',
      'sched:',
      'fan:',
      'sched:dev-1',
      'fan:not-a-uuid',
      'sched: $_uuid',
      'sched:$_uuid/extra',
      'timer:$_uuid',
      _uuid,
      '{"notification_id":""}',
      '{"notification_id":7}',
      '{"kind":"x"}',
      '[1,2]',
      '{broken',
    ]) {
      expect(parseLocalNotificationPayload(payload), isNull, reason: payload);
    }
  });

  test('fan payload builder uses the same prefix the parser reads', () {
    expect(fanNotificationPayload(_uuid), 'fan:$_uuid');
    expect(parseLocalNotificationPayload(fanNotificationPayload(_uuid)),
        const DeviceNotificationTarget(DeviceNotificationKind.fan, _uuid));
  });
}
