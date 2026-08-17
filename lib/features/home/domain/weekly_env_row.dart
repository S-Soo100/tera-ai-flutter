import '../../my_cage/domain/telemetry_bucket.dart';
import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/chart_window.dart';

/// 홈 "이번 주" 목록의 한 행 — 애플 날씨 10일 예보의 하루.
///
/// `요일 | 분무 횟수 | 최저° | ━ 범위 바 ━ | 최고° | 습도 평균%`.
/// 하루 경계는 07:00([ChartWindow.dayBoundaryHour])이라 [day]는 그 07:00이다.
class WeeklyEnvRow {
  /// 이 행의 하루 시작(07:00).
  final DateTime day;

  /// 진행 중인 오늘인가. 오늘 행만 바 위에 **현재 온도 점**을 찍는다.
  final bool isToday;

  /// 그날 최저/최고 온도. 값이 없는 날은 null — 바를 그리지 않는다.
  final double? tMin;
  final double? tMax;

  /// 그날 평균 습도. 우측 끝 보조 숫자.
  final double? hAvg;

  /// 그날 분무 횟수(`commands` 이력의 acked 분무 명령 수).
  final int mistCount;

  const WeeklyEnvRow({
    required this.day,
    required this.isToday,
    required this.tMin,
    required this.tMax,
    required this.hAvg,
    required this.mistCount,
  });

  bool get hasRange => tMin != null && tMax != null;

  /// 이 행이 덮는 구간 끝(다음 07:00, exclusive).
  DateTime get dayEnd => DateTime(day.year, day.month, day.day + 1, day.hour);
}

/// "이번 주" 7행 + 바 정규화 기준.
///
/// 트랙은 **이번 주 전체의 min~max**다 — 모든 행이 같은 축을 써야 "어제가
/// 오늘보다 더웠다"가 바 길이로 읽힌다. 행마다 축을 잡으면 전부 꽉 찬 바가 된다.
class WeeklyEnvRows {
  /// 오늘이 맨 위, 아래로 과거 6일.
  final List<WeeklyEnvRow> rows;

  /// 트랙 양 끝. 값이 하나도 없으면 null.
  final double? trackMin;
  final double? trackMax;

  const WeeklyEnvRows({
    required this.rows,
    required this.trackMin,
    required this.trackMax,
  });

  static const empty = WeeklyEnvRows(rows: [], trackMin: null, trackMax: null);

  bool get hasData => rows.any((r) => r.hasRange);

  /// [ChartWindow.homeWeekly] 창을 [rollupByDay]로 접은 일간 버킷(오래된 날
  /// 먼저, 마지막이 오늘)과 창 구간의 기기 마커로 행을 만든다.
  ///
  /// [days]는 창의 [ChartWindow.tickCount]개(7)여야 한다. 모자라면 있는
  /// 만큼만 행을 만든다 — 자리를 지어내지 않는다.
  factory WeeklyEnvRows.from({
    required List<TelemetryBucket> days,
    required ChartWindow window,
    required List<ActuatorMarker> markers,
  }) {
    if (days.isEmpty) return empty;

    final todayStart = ChartWindow.lastDayBoundaryOnOrBefore(window.now);
    final rows = <WeeklyEnvRow>[];
    double? lo;
    double? hi;

    for (var i = 0; i < days.length; i++) {
      final dayStart = DateTime(window.start.year, window.start.month,
          window.start.day + i, window.start.hour);
      final b = days[i];
      // rollupByDay는 스탬프를 하루 중앙(+12h)에 찍는다 — 여기서는 창 시작
      // 기준 i번째 날로 다시 잡는다(중앙값에서 역산하면 서머타임에 흔들린다).
      final row = WeeklyEnvRow(
        day: dayStart,
        isToday: dayStart.isAtSameMomentAs(todayStart),
        tMin: b.tMin,
        tMax: b.tMax,
        hAvg: b.hAvg,
        mistCount: _countMist(markers, dayStart),
      );
      final tMin = row.tMin;
      final tMax = row.tMax;
      if (tMin != null && (lo == null || tMin < lo)) lo = tMin;
      if (tMax != null && (hi == null || tMax > hi)) hi = tMax;
      rows.add(row);
    }

    // 오늘이 맨 위 — 애플 날씨는 미래로 내려가지만 우리는 과거로 내려간다.
    return WeeklyEnvRows(
      rows: rows.reversed.toList(growable: false),
      trackMin: lo,
      trackMax: hi,
    );
  }

  static int _countMist(List<ActuatorMarker> markers, DateTime dayStart) {
    final dayEnd = DateTime(
        dayStart.year, dayStart.month, dayStart.day + 1, dayStart.hour);
    var n = 0;
    for (final m in markers) {
      if (m.kind != MarkerKind.mist) continue;
      if (m.at.isBefore(dayStart) || !m.at.isBefore(dayEnd)) continue;
      n++;
    }
    return n;
  }

  /// [value]의 트랙 위 위치(0~1). 트랙이 없거나 폭이 0이면 null.
  ///
  /// 0~1로 **클램프**한다 — 오늘 실시간 값은 30분 집계보다 최신이라 그날
  /// max를 잠깐 넘을 수 있는데, 점이 바 밖으로 튀어나가면 고장으로 읽힌다.
  double? positionOf(double? value) {
    if (value == null || trackMin == null || trackMax == null) return null;
    final span = trackMax! - trackMin!;
    if (span <= 0) return 0.5;
    return ((value - trackMin!) / span).clamp(0.0, 1.0);
  }
}
