import '../../features/my_cage/domain/telemetry_bucket.dart';

/// 온습도 상세 주간의 **월요일 시작 7일 창** (계획서 2026-09-02 T3, §A.6).
///
/// [ChartWindow.weekly](07:00 경계, 완결 7일)와 다르다 — 온습도 상세는 달력
/// 주(월~일, 자정 경계) 페이징이다. 혼용 금지.
class WeekRange {
  /// 자정으로 정규화된 그 주 월요일 (로컬).
  final DateTime monday;

  const WeekRange(this.monday);

  /// [day]가 속한 주. `DateTime.weekday`는 월요일이 1이다.
  factory WeekRange.containing(DateTime day) => WeekRange(
        DateTime(day.year, day.month, day.day - (day.weekday - 1)),
      );

  /// 주의 시작(포함) = 월요일 자정.
  DateTime get start => monday;

  /// 주의 끝(제외) = 다음 월요일 자정. 달력 연산이라 월말·서머타임에도 안전.
  DateTime get end =>
      DateTime(monday.year, monday.month, monday.day + 7);

  WeekRange get previous =>
      WeekRange(DateTime(monday.year, monday.month, monday.day - 7));

  WeekRange get next =>
      WeekRange(DateTime(monday.year, monday.month, monday.day + 7));

  /// 월~일 7일의 자정 목록. 요일 축이 항상 7칸이어야 하므로 여기서 만든다.
  List<DateTime> get days => [
        for (var i = 0; i < 7; i++)
          DateTime(monday.year, monday.month, monday.day + i),
      ];

  // StateProvider 상태로 쓰므로 값 동등성이 필요하다 (EnvDay와 같은 이유).
  @override
  bool operator ==(Object other) => other is WeekRange && other.monday == monday;

  @override
  int get hashCode => monday.hashCode;

  @override
  String toString() =>
      'WeekRange(${monday.year}-${monday.month}-${monday.day}~)';
}

/// 요일 하나의 min/max. 데이터가 없는 날은 min/max가 null이다 —
/// **목록에서 빼지 않는다.** 빼면 7칸 축이 줄어 요일이 밀린다.
class DayMinMax {
  /// 자정 정규화된 로컬 날짜.
  final DateTime day;
  final double? min;
  final double? max;

  const DayMinMax({required this.day, this.min, this.max});
}

/// [week] 창의 요일별 **온도** min/max — 항상 7칸 고정 리스트.
///
/// 버킷 스탬프는 UTC로 올 수 있으니 **로컬 달력 날짜**로 접는다(자정 경계 =
/// B.4 결정). 07:00 경계의 [rollupByDay]를 여기 쓰면 안 된다 — 새벽 데이터가
/// 전날로 넘어가 요일이 어긋난다.
///
/// ⚠️ 0 이하 값은 버린다 — `telemetry_30m`의 0은 센서 오프라인 센티넬이지
/// 실측이 아니다 (메모리 `project_telemetry_zero_sentinel`).
List<DayMinMax> weekTempRanges(
  List<TelemetryBucket> dailyBuckets,
  WeekRange week,
) =>
    _weekRanges(dailyBuckets, week, (b) => (min: b.tMin, max: b.tMax));

/// [week] 창의 요일별 **습도** min/max. 규칙은 [weekTempRanges]와 같다.
List<DayMinMax> weekHumidRanges(
  List<TelemetryBucket> dailyBuckets,
  WeekRange week,
) =>
    _weekRanges(dailyBuckets, week, (b) => (min: b.hMin, max: b.hMax));

List<DayMinMax> _weekRanges(
  List<TelemetryBucket> buckets,
  WeekRange week,
  ({double? min, double? max}) Function(TelemetryBucket) pick,
) {
  final days = week.days;
  final mins = List<double?>.filled(7, null);
  final maxs = List<double?>.filled(7, null);

  for (final b in buckets) {
    final local = b.bucket.toLocal();
    final dayStart = DateTime(local.year, local.month, local.day);
    if (dayStart.isBefore(week.start) || !dayStart.isBefore(week.end)) {
      continue; // 주 밖.
    }
    final i = dayStart.difference(week.start).inDays;
    if (i < 0 || i > 6) continue; // 방어 — 서머타임 등으로 어긋난 경우.
    final v = pick(b);
    final lo = v.min;
    final hi = v.max;
    if (lo != null && lo > 0) {
      mins[i] = mins[i] == null || lo < mins[i]! ? lo : mins[i];
    }
    if (hi != null && hi > 0) {
      maxs[i] = maxs[i] == null || hi > maxs[i]! ? hi : maxs[i];
    }
  }

  return [
    for (var i = 0; i < 7; i++)
      DayMinMax(day: days[i], min: mins[i], max: maxs[i]),
  ];
}
