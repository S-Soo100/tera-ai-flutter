import 'activity_window.dart';

enum ActivityQuality { exact, legacyEstimate, mixed }

enum ActivityOrigin { exact, legacy, currentCamera }

enum ActivityObservation {
  complete,
  inProgress,
  missing,
  beforeConnection,
  future
}

/// A real assignment boundary, or an explicitly inherited legacy scope.
/// A legacy null start is deliberately not replaced with pet.createdAt.
/// currentCamera is an unbounded display scope, not historical membership.
class ActivityAssignment {
  ActivityAssignment(
      {required this.cameraId,
      this.startUtc,
      this.endUtc,
      this.origin = ActivityOrigin.exact}) {
    if (origin == ActivityOrigin.exact && startUtc == null) {
      {
        throw ArgumentError('Exact assignments require a real start instant');
      }
    }
    if (startUtc != null && endUtc != null && !endUtc!.isAfter(startUtc!)) {
      {
        throw ArgumentError('Assignment end must follow start');
      }
    }
  }
  ActivityAssignment.currentCamera(String cameraId)
      : this(cameraId: cameraId, origin: ActivityOrigin.currentCamera);

  final String cameraId;
  final DateTime? startUtc;
  final DateTime? endUtc;
  final ActivityOrigin origin;
  @override
  bool operator ==(Object other) =>
      other is ActivityAssignment &&
      other.cameraId == cameraId &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc &&
      other.origin == origin;
  @override
  int get hashCode => Object.hash(cameraId, startUtc, endUtc, origin);
}

class ActivityInterval {
  ActivityInterval(
      {required this.cameraId,
      required this.startUtc,
      required this.endUtc,
      this.quality = ActivityQuality.exact}) {
    if (!endUtc.isAfter(startUtc)) {
      throw ArgumentError('Empty activity interval');
    }
  }
  final String cameraId;
  final DateTime startUtc;
  final DateTime endUtc;
  final ActivityQuality quality;
}

/// Collection coverage, never video count or GME analysis coverage.
/// Current owner-activity-v1 does not provide these records.
class ActivityCoverage {
  const ActivityCoverage(
      {required this.cameraId,
      required this.startUtc,
      required this.endUtc,
      required this.state});
  final String cameraId;
  final DateTime startUtc;
  final DateTime endUtc;
  final ActivityObservation state;
}

/// 서버 수집 coverage 계약이 없을 때의 관측 완료 가정 — **2026-09-16 사용자 결정**.
///
/// 카메라는 움직임이 있을 때만 녹화하므로 영상이 없는 날은 "조용한 날(활동 0)"이
/// 정상 동작이다. 그래서 카메라가 연결된 기간의 **이미 지난 시간은 전부 관측
/// 완료**로 보고, 영상이 없는 날은 활동 0으로 평균에 넣는다. 카메라가 꺼져 있던
/// 날도 0으로 들어가는 오차는 감수하기로 했고, 온라인 구간 계약은 요청하지
/// 않는다. 서버가 coverage를 주면 그 값이 우선한다(호출부가 비어 있을 때만 쓴다).
///
/// 09-15 확정("미수집은 제외")과 petcam-lab 계약 노트("no_video를 0으로 세지
/// 말 것")를 사용자가 이 결정으로 바꿨다 — RESULTS.md §10 12번.
List<ActivityCoverage> assumedCoverage(
    {required List<ActivityAssignment> assignments,
    required ActivityWindow window,
    required DateTime now}) {
  final upper = now.isBefore(window.endUtc) ? now.toUtc() : window.endUtc;
  return [
    for (final a in assignments)
      if (_clip(a.startUtc ?? window.startUtc, a.endUtc ?? upper,
              window.startUtc, upper)
          case final span?)
        ActivityCoverage(
            cameraId: a.cameraId,
            startUtc: span.start,
            endUtc: span.end,
            state: ActivityObservation.complete),
  ];
}

class ActivityBucket {
  const ActivityBucket(
      {required this.window,
      required this.seconds,
      required this.state,
      required this.isEstimated});
  final ActivityWindow window;

  /// Null means no measured value, not zero activity.
  final double? seconds;
  final ActivityObservation state;
  final bool isEstimated;
}

class ActivityDaySummary extends ActivityBucket {
  const ActivityDaySummary(
      {required super.window,
      required super.seconds,
      required super.state,
      required super.isEstimated,
      required this.hours});
  final List<ActivityBucket> hours;

  /// 평균 분모에 드는 날. **2026-09-16 사용자 결정**: 추정(legacy) 영상만 있는
  /// 날도 추정값 그대로 평균에 넣는다 — 추정일을 빼고 빈 날만 0으로 세면
  /// 추정 데이터만 있는 계정의 평균이 늘 0·`--`가 된다(시뮬 확인).
  bool get isComplete => state == ActivityObservation.complete;

  /// 완료이면서 추정이 섞이지 않은 날(정확 관측).
  bool get isExact => isComplete && !isEstimated;
}

class ActivityAverage {
  const ActivityAverage(
      {required this.seconds,
      required this.completedDays,
      this.isEstimated = false});
  final double? seconds;
  final int completedDays;

  /// 분모에 추정(legacy) 활동일이 하나라도 있으면 true — 화면은 '추정' 표기.
  final bool isEstimated;
}

class ActivityWeekSummary {
  const ActivityWeekSummary({required this.window, required this.days});
  final ActivityWindow window;
  final List<ActivityDaySummary> days;
  double? get seconds => _sumKnown(days.map((d) => d.seconds));
  bool get isEstimated => days.any((d) => d.isEstimated);
  ActivityAverage get average => _average(days.where((d) => d.isComplete));
}

ActivityAverage previousActivityAverage(
    ActivityWindow selected, Iterable<ActivityDaySummary> days) {
  final start = selected.startUtc.subtract(const Duration(days: 7));
  return _average(days.where((d) =>
      d.isComplete &&
      !d.window.startUtc.isBefore(start) &&
      d.window.startUtc.isBefore(selected.startUtc)));
}

ActivityAverage _average(Iterable<ActivityDaySummary> values) {
  final days = values.toList();
  return ActivityAverage(
      isEstimated: days.any((d) => d.isEstimated),
      seconds: days.isEmpty
          ? null
          : days.fold<double>(0, (sum, d) => sum + (d.seconds ?? 0)) /
              days.length,
      completedDays: days.length);
}

double? _sumKnown(Iterable<double?> values) {
  final known = values.whereType<double>().toList();
  return known.isEmpty ? null : known.fold<double>(0, (a, b) => a + b);
}

typedef _Span = ({DateTime start, DateTime end});
_Span? _clip(DateTime start, DateTime end, DateTime lower, DateTime upper) {
  final s = start.isAfter(lower) ? start : lower;
  final e = end.isBefore(upper) ? end : upper;
  return e.isAfter(s) ? (start: s, end: e) : null;
}

List<_Span> _union(List<_Span> spans) {
  spans.sort((a, b) => a.start.compareTo(b.start));
  final result = <_Span>[];
  for (final span in spans) {
    if (result.isEmpty || span.start.isAfter(result.last.end)) {
      result.add(span);
    } else if (span.end.isAfter(result.last.end)) {
      result[result.length - 1] = (start: result.last.start, end: span.end);
    }
  }
  return result;
}

double _seconds(List<_Span> spans) => _union(spans).fold<double>(
    0, (sum, s) => sum + s.end.difference(s.start).inMicroseconds / 1000000);

ActivityDaySummary aggregateActivityDay(
    {required ActivityWindow window,
    required List<ActivityInterval> intervals,
    required List<ActivityAssignment> assignments,
    required List<ActivityCoverage> coverage,
    required DateTime now}) {
  ActivityBucket bucket(ActivityWindow range) {
    if (!range.startUtc.isBefore(now)) {
      return ActivityBucket(
          window: range,
          seconds: null,
          state: ActivityObservation.future,
          isEstimated: false);
    }
    final upper = now.isBefore(range.endUtc) ? now.toUtc() : range.endUtc;
    final allowed = <({ActivityAssignment assignment, _Span span})>[];
    for (final a in assignments) {
      final span = _clip(a.startUtc ?? range.startUtc, a.endUtc ?? upper,
          range.startUtc, upper);
      if (span != null) allowed.add((assignment: a, span: span));
    }
    final firstStarts = assignments
        .map((a) => a.startUtc)
        .whereType<DateTime>()
        .toList()
      ..sort();
    final before = allowed.isEmpty &&
        assignments.every((a) => a.origin != ActivityOrigin.legacy) &&
        firstStarts.isNotEmpty &&
        !range.endUtc.isAfter(firstStarts.first);
    final spans = <_Span>[];
    final completed = <_Span>[];
    final processing = <_Span>[];
    var estimated = false;
    for (final a in allowed) {
      for (final i
          in intervals.where((i) => i.cameraId == a.assignment.cameraId)) {
        final span = _clip(i.startUtc, i.endUtc, a.span.start, a.span.end);
        if (span == null) continue;
        spans.add(span);
        estimated |= i.quality != ActivityQuality.exact;
      }
      for (final c
          in coverage.where((c) => c.cameraId == a.assignment.cameraId)) {
        final span = _clip(c.startUtc, c.endUtc, a.span.start, a.span.end);
        if (span == null) continue;
        if (c.state == ActivityObservation.complete) completed.add(span);
        if (c.state == ActivityObservation.inProgress) processing.add(span);
      }
    }
    // A day with an assignment gap is not a completed observation day.
    final duration =
        range.endUtc.difference(range.startUtc).inMicroseconds / 1000000;
    final isComplete =
        !range.endUtc.isAfter(now) && _seconds(completed) >= duration;
    final isCurrent = range.startUtc.isBefore(now) && range.endUtc.isAfter(now);
    final state = before
        ? ActivityObservation.beforeConnection
        : isComplete
            ? ActivityObservation.complete
            : processing.isNotEmpty || (isCurrent && allowed.isNotEmpty)
                ? ActivityObservation.inProgress
                : ActivityObservation.missing;
    return ActivityBucket(
        window: range,
        seconds: spans.isNotEmpty
            ? _seconds(spans)
            : isComplete
                ? 0
                : null,
        state: state,
        isEstimated: estimated);
  }

  final hours = List<ActivityBucket>.generate(
      24,
      (h) => bucket(ActivityWindow(
          startUtc: window.startUtc.add(Duration(hours: h)),
          endUtc: window.startUtc.add(Duration(hours: h + 1)))));
  final total = bucket(window);
  return ActivityDaySummary(
      window: window,
      seconds: _sumKnown(hours.map((h) => h.seconds)),
      state: total.state,
      isEstimated: total.isEstimated,
      hours: List.unmodifiable(hours));
}
