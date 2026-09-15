import 'package:vivanaut/features/home/data/schedule_repository.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';

/// 예약 화면 레이아웃·캡처 테스트용 대역 — 네트워크 없이 목록만 돌려준다.
/// (동작 검증은 `routine_settings_screen_test.dart`의 기록형 대역이 맡는다.)
class FakeScheduleRepo implements ScheduleRepository {
  FakeScheduleRepo([this.items = const []]);
  List<Schedule> items;

  @override
  Future<List<Schedule>> list(String deviceId) async => items;

  @override
  Future<Schedule> patch(String id, Map<String, dynamic> changes) async {
    final s = items.firstWhere((e) => e.id == id);
    final updated =
        s.copyWith(enabled: changes['enabled'] as bool? ?? s.enabled);
    items = [
      for (final e in items)
        if (e.id == id) updated else e
    ];
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final target = items.where((e) => e.id == id).firstOrNull;
    items = items
        .where((e) =>
            e.id != id &&
            !(target?.pairId != null && e.pairId == target!.pairId))
        .toList();
  }

  @override
  Future<Schedule> create(String deviceId,
          {required ScheduleAction action,
          required ScheduleKind kind,
          required int hour,
          required int minute,
          required List<int> daysOfWeek,
          Map<String, dynamic>? payload,
          ScheduleGuard? guard,
          String? pairId}) async =>
      fixtureSchedule(
          id: 'new-${items.length}',
          action: action,
          kind: kind,
          hour: hour,
          minute: minute,
          days: daysOfWeek,
          pairId: pairId);
}

Schedule fixtureSchedule({
  required String id,
  required ScheduleAction action,
  int hour = 12,
  int minute = 0,
  ScheduleKind kind = ScheduleKind.weekly,
  List<int> days = const [6, 7],
  bool enabled = true,
  String? pairId,
  Map<String, dynamic>? payload,
}) =>
    Schedule(
      id: id,
      deviceId: 'd1',
      action: action,
      payload: payload,
      kind: kind,
      hour: hour,
      minute: minute,
      daysOfWeek: days,
      enabled: enabled,
      guard: null,
      pairId: pairId,
      nextRunAt: null,
      lastRunAt: null,
    );

/// Figma 1106:5317 세 줄 — 환기팬 12:00~15:30 켜짐 / LED 꺼짐 / 냉각팬 켜짐, 토·일.
List<Schedule> figmaScheduleRows() => [
      fixtureSchedule(id: 'f-on', action: ScheduleAction.fanOn, pairId: 'f'),
      fixtureSchedule(
          id: 'f-off',
          action: ScheduleAction.fanOff,
          hour: 15,
          minute: 30,
          pairId: 'f'),
      fixtureSchedule(
          id: 'l-on',
          action: ScheduleAction.ledOn,
          pairId: 'l',
          enabled: false),
      fixtureSchedule(
          id: 'l-off',
          action: ScheduleAction.ledOff,
          hour: 15,
          minute: 30,
          pairId: 'l',
          enabled: false),
      fixtureSchedule(id: 'c-on', action: ScheduleAction.fan2On, pairId: 'c'),
      fixtureSchedule(
          id: 'c-off',
          action: ScheduleAction.fan2Off,
          hour: 15,
          minute: 30,
          pairId: 'c'),
    ];
