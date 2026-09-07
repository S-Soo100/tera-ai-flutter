import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/schedule.dart';
import 'package:vivnanaut/features/home/domain/schedule_notification_plan.dart';
import 'package:vivnanaut/shared/domain/fan_timer_notification_plan.dart';

Schedule _sched({
  String id = 's1',
  ScheduleAction action = ScheduleAction.mist,
  ScheduleKind kind = ScheduleKind.daily,
  int hour = 9,
  int minute = 15,
  List<int> days = const [],
  bool enabled = true,
  ScheduleGuard? guard,
}) =>
    Schedule(
      id: id,
      deviceId: 'd1',
      action: action,
      payload: null,
      kind: kind,
      hour: hour,
      minute: minute,
      daysOfWeek: days,
      enabled: enabled,
      guard: guard,
      nextRunAt: null,
      lastRunAt: null,
    );

void main() {
  group('scheduleNotificationSpecs', () {
    test('daily 예약 1건 → 매일 반복 스펙 1건 (weekday null)', () {
      final specs = scheduleNotificationSpecs([_sched()]);
      expect(specs, hasLength(1));
      expect(specs.first.weekday, isNull);
      expect(specs.first.hour, 9);
      expect(specs.first.minute, 15);
      expect(specs.first.actionDisplayKey, 'routine_action_mist');
    });

    test('weekly 예약 → 요일 수만큼 스펙이 갈라진다', () {
      final specs = scheduleNotificationSpecs([
        _sched(kind: ScheduleKind.weekly, days: const [1, 3, 5]),
      ]);
      expect(specs.map((s) => s.weekday), [1, 3, 5]);
      // 같은 예약이라도 요일별 알림 id는 서로 달라야 한다 — 겹치면 마지막
      // 요일 하나만 남는다.
      expect(specs.map((s) => s.id).toSet(), hasLength(3));
    });

    test('꺼진 예약은 알림을 만들지 않는다', () {
      expect(scheduleNotificationSpecs([_sched(enabled: false)]), isEmpty);
    });

    test('가드 걸린 예약은 guarded 표시 — 문구가 "건너뛸 수 있음"을 밝힌다', () {
      final specs = scheduleNotificationSpecs([
        _sched(
            guard: const ScheduleGuard(
                type: GuardType.humidityAbove, value: 80, enabled: true)),
        _sched(
            id: 's2',
            guard: const ScheduleGuard(
                type: GuardType.humidityAbove, value: 80, enabled: false)),
      ]);
      expect(specs[0].guarded, isTrue);
      // 가드가 꺼져 있으면 서버도 무시한다 — 문구도 조건을 언급하지 않는다.
      expect(specs[1].guarded, isFalse);
    });

    test('알림 id는 예약 id 기반으로 안정적 — 재동기화해도 같은 id를 덮어쓴다', () {
      final a = scheduleNotificationSpecs([_sched()]).first.id;
      final b = scheduleNotificationSpecs([_sched()]).first.id;
      expect(a, b);
      expect(a, notificationIdFor('sched:s1:0'));
    });
  });

  group('nextOccurrence', () {
    final mon0900 = DateTime(2026, 8, 24, 9, 0); // 2026-08-24 = 월요일

    test('daily — 오늘 시각이 아직 안 지났으면 오늘', () {
      expect(nextOccurrence(mon0900, 9, 15, null), DateTime(2026, 8, 24, 9, 15));
    });

    test('daily — 이미 지났으면 내일', () {
      expect(nextOccurrence(mon0900, 8, 0, null), DateTime(2026, 8, 25, 8, 0));
    });

    test('daily — 정확히 같은 시각이면 다음날로 민다 (과거 예약 방지)', () {
      expect(nextOccurrence(mon0900, 9, 0, null), DateTime(2026, 8, 25, 9, 0));
    });

    test('weekly — 같은 주 뒤 요일', () {
      // 월 09:00 기준 수(3) 10:00 → 이번 주 수요일
      expect(nextOccurrence(mon0900, 10, 0, 3), DateTime(2026, 8, 26, 10, 0));
    });

    test('weekly — 오늘 요일인데 시각이 지났으면 다음 주', () {
      expect(nextOccurrence(mon0900, 8, 0, 1), DateTime(2026, 8, 31, 8, 0));
    });

    test('weekly — 지나간 요일이면 다음 주로 감는다', () {
      // 월요일 기준 일요일(7) → 이번 주 일요일 8/30
      expect(nextOccurrence(mon0900, 9, 0, 7), DateTime(2026, 8, 30, 9, 0));
    });
  });
}
