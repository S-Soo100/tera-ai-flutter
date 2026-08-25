/// 예약(스케줄) → 로컬 알림 스펙 전개 (순수 로직, 2026-08-25).
///
/// 예약 실행은 서버가 하고 폰은 실행 순간을 모른다(FCM 보류). 그래서 폰이
/// 아는 예약 목록으로 **실행 시각에 맞춘 반복 로컬 알림**을 예약한다 —
/// daily는 매일, weekly는 요일별 반복. 배선은 `ScheduleNotificationSync`.
///
/// 한계(수용): 다른 폰에서 예약을 바꾸면 이 폰은 다음 동기화(예약 화면 진입/
/// 수정) 전까지 옛 알림을 유지한다. 가드로 서버가 실행을 건너뛴 경우에도
/// 알림은 울린다 — 그래서 가드 예약은 문구에 "건너뛸 수 있음"을 밝힌다.
library;

import '../../../shared/domain/fan_timer_notification_plan.dart';
import 'schedule.dart';

class ScheduleNotificationSpec {
  const ScheduleNotificationSpec({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekday,
    required this.actionDisplayKey,
    required this.guarded,
  });

  /// OS 알림 id. `sched:{scheduleId}:{weekday|0}` 해시 — 같은 예약을 재동기화
  /// 하면 같은 id를 덮어써 중복 알림이 쌓이지 않는다.
  final int id;

  final int hour;
  final int minute;

  /// 1=월 … 7=일 (Dart `DateTime.weekday`). null이면 daily(매일 반복).
  final int? weekday;

  /// 알림 제목에 넣을 동작 표시명 i18n 키 (`routine_action_*`).
  final String actionDisplayKey;

  /// 가드(스킵 조건)가 켜져 있는가 — 문구가 "건너뛸 수 있음"을 밝혀야 한다.
  final bool guarded;
}

/// 예약 목록 → 알림 스펙. 꺼진 예약은 제외한다.
List<ScheduleNotificationSpec> scheduleNotificationSpecs(
  List<Schedule> schedules,
) {
  final out = <ScheduleNotificationSpec>[];
  for (final s in schedules) {
    if (!s.enabled) continue;
    final guarded = s.guard?.enabled ?? false;
    final days = s.kind == ScheduleKind.weekly ? s.daysOfWeek : const <int>[];
    if (days.isEmpty) {
      out.add(ScheduleNotificationSpec(
        id: notificationIdFor('sched:${s.id}:0'),
        hour: s.hour,
        minute: s.minute,
        weekday: null,
        actionDisplayKey: s.action.displayKey,
        guarded: guarded,
      ));
    } else {
      for (final d in days) {
        out.add(ScheduleNotificationSpec(
          id: notificationIdFor('sched:${s.id}:$d'),
          hour: s.hour,
          minute: s.minute,
          weekday: d,
          actionDisplayKey: s.action.displayKey,
          guarded: guarded,
        ));
      }
    }
  }
  return out;
}

/// [now] 이후 첫 발화 시각. 반복 알림의 시작점으로 쓴다 — 플러그인이 과거
/// 시각 예약을 거부하므로 항상 미래여야 한다. 같은 시각은 다음 회차로 민다.
DateTime nextOccurrence(DateTime now, int hour, int minute, int? weekday) {
  var t = DateTime(now.year, now.month, now.day, hour, minute);
  if (weekday == null) {
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }
  // Dart의 %는 양수 제수에 대해 항상 0 이상 — 지나간 요일은 다음 주로 감긴다.
  t = t.add(Duration(days: (weekday - t.weekday) % 7));
  if (!t.isAfter(now)) t = t.add(const Duration(days: 7));
  return t;
}
