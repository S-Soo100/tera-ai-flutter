import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/fan_timer_notification_plan.dart';

void main() {
  group('FanTimerNotificationPlan.of', () {
    test('duration 붙은 fan_on → 예약', () {
      final plan = FanTimerNotificationPlan.of('fan_on', 1800000);
      expect(plan, isA<ScheduleFanDone>());
      expect((plan as ScheduleFanDone).minutes, 30);
    });

    test('duration 없는 fan_on(계속 켜기) → 취소 — 기존 타이머를 대체한다', () {
      expect(FanTimerNotificationPlan.of('fan_on', null), isA<CancelFanDone>());
    });

    test('fan_off → 취소', () {
      expect(FanTimerNotificationPlan.of('fan_off', null), isA<CancelFanDone>());
      // 방어: off에 duration이 실려 와도 취소다.
      expect(
          FanTimerNotificationPlan.of('fan_off', 60000), isA<CancelFanDone>());
    });

    test('0 이하 duration의 fan_on → 취소 취급 (예약할 시간이 없다)', () {
      expect(FanTimerNotificationPlan.of('fan_on', 0), isA<CancelFanDone>());
      expect(FanTimerNotificationPlan.of('fan_on', -5), isA<CancelFanDone>());
    });

    test('팬 이외 명령 → null', () {
      for (final action in ['heater_on', 'mist', 'led_on', 'relay_off']) {
        expect(FanTimerNotificationPlan.of(action, 1000), isNull,
            reason: action);
      }
    });

    test('fan_toggle → null — 앱은 더 이상 안 보내고, 상태를 모르니 예약도 못 건다', () {
      expect(FanTimerNotificationPlan.of('fan_toggle', null), isNull);
    });
  });

  group('notificationIdFor', () {
    test('같은 기기 → 항상 같은 id (재시작 후에도 취소 가능해야 한다)', () {
      const uuid = 'a3f1c9e2-7b64-4d20-9c11-2f8e5d6a0b34';
      expect(notificationIdFor(uuid), notificationIdFor(uuid));
      // String.hashCode는 실행 간 안정이 보장되지 않아 못 쓴다 — FNV-1a 고정
      // 구현이므로 값 자체를 못박아 회귀를 잡는다.
      expect(notificationIdFor(uuid), 1035437640);
    });

    test('항상 32비트 양수 — Android 알림 id 범위', () {
      for (final id in ['', 'x', 'device-1', 'device-2', '한글도']) {
        final n = notificationIdFor(id);
        expect(n, greaterThanOrEqualTo(0), reason: id);
        expect(n, lessThanOrEqualTo(0x7FFFFFFF), reason: id);
      }
    });

    test('다른 기기는 다른 id', () {
      expect(notificationIdFor('device-1'),
          isNot(notificationIdFor('device-2')));
    });
  });
}
