import '../../../shared/domain/night_band.dart';

/// "오늘 밤" 카드의 진행 상태 (B안 비행 진행 바 문법, 2026-08-18).
///
/// 밤 창은 [kNightStartHour]~[kNightEndHour](22:00~06:00, 기획안 §3.1 ②) —
/// 차트 밤 띠와 **같은 상수**를 쓴다. 집계 규칙이 바뀌면 둘이 같이 움직인다.
///
/// 벽시계 기준이다. `Duration(days: 1)` 덧셈이 아니라 `DateTime` 생성자로
/// 날짜를 넘긴다 — DST 타임존에서 22:00이 21:00/23:00으로 밀리지 않게.
class NightProgress {
  const NightProgress._({
    required this.start,
    required this.end,
    required this.isRunning,
    required this.progress,
    required this.untilNext,
  });

  /// 표시할 밤 창의 시작(22:00). 밤이 진행 중이면 그 밤, 아니면 **다음** 밤.
  final DateTime start;

  /// 표시할 밤 창의 끝(익일 06:00).
  final DateTime end;

  /// 지금이 밤 창 안인가.
  final bool isRunning;

  /// 진행률 0~1. 밤이 아니면 0.
  final double progress;

  /// 다음 밤 시작까지 남은 시간. 밤이 진행 중이면 [Duration.zero].
  final Duration untilNext;

  factory NightProgress.at(DateTime now) {
    // 오늘 22:00에 시작하는 밤과, 어제 22:00에 시작해 오늘 06:00에 끝나는 밤.
    final tonightStart =
        DateTime(now.year, now.month, now.day, kNightStartHour);
    final lastNightStart =
        DateTime(now.year, now.month, now.day - 1, kNightStartHour);

    for (final s in [lastNightStart, tonightStart]) {
      final e = DateTime(s.year, s.month, s.day + 1, kNightEndHour);
      if (!now.isBefore(s) && now.isBefore(e)) {
        final total = e.difference(s).inMicroseconds;
        final done = now.difference(s).inMicroseconds;
        return NightProgress._(
          start: s,
          end: e,
          isRunning: true,
          progress: total <= 0 ? 0 : (done / total).clamp(0.0, 1.0),
          untilNext: Duration.zero,
        );
      }
    }

    // 낮이다 — 다음 밤은 오늘 22:00 (06:00 이후 낮이므로 항상 오늘).
    return NightProgress._(
      start: tonightStart,
      end: DateTime(tonightStart.year, tonightStart.month, tonightStart.day + 1,
          kNightEndHour),
      isRunning: false,
      progress: 0,
      untilNext: tonightStart.difference(now),
    );
  }
}
