import '../../my_cage/domain/telemetry_bucket.dart';
import '../../../shared/domain/actuator_marker.dart';

/// 홈 "지난 24시간" 스트립의 한 칸 — 애플 날씨 시간별 예보의 한 시간.
///
/// `시각 / 기기 동작 아이콘 / 온도°`. 맨 왼쪽은 "지금", 그 뒤로 3시간 간격의
/// 정각 8칸이 **과거로** 이어진다(애플은 미래로 가지만 우리는 기록이다).
class HourlyEnvSlot {
  /// 이 칸의 대표 시각. [isNow]면 계산 시각 그 자체.
  final DateTime at;

  /// "지금" 칸인가.
  final bool isNow;

  /// 표시 온도. 그 시각 30분 버킷의 평균(지금 칸은 실시간 값 우선). 없으면 null.
  final double? temp;

  /// 이 칸이 덮는 구간에서 돈 기기 동작 종류. 비어 있으면 아이콘 자리에 점.
  final Set<MarkerKind> kinds;

  const HourlyEnvSlot({
    required this.at,
    required this.isNow,
    required this.temp,
    required this.kinds,
  });

  /// 정수 반올림 온도. 애플처럼 소수는 뺀다 — 이 칸은 훑는 자리다.
  int? get tempRounded => temp?.round();
}

/// 스트립 데이터 조립.
class HourlyEnvSlots {
  HourlyEnvSlots._();

  /// 칸 간격(시간).
  static const int stepHours = 3;

  /// "지금"을 뺀 과거 칸 수. 3h × 8 = 24h.
  static const int pastSlots = 8;

  /// 온도를 붙일 때 허용하는 버킷 시각 오차. 30분 버킷이라 그 안이면 "그 시각".
  static const Duration bucketTolerance = Duration(minutes: 30);

  /// [buckets]는 24시간 창의 30분 버킷(시각 순서 무관), [markers]는 같은 창의
  /// 기기 동작. [currentTemp]는 실시간 값 — 있으면 "지금" 칸이 이걸 쓴다.
  ///
  /// 마커는 **인접 칸 대표 시각의 중점**으로 나눠 정확히 한 칸에만 속한다 —
  /// 구간을 겹치게 잡으면 분무 한 번이 두 칸에 찍힌다.
  static List<HourlyEnvSlot> build({
    required DateTime now,
    required List<TelemetryBucket> buckets,
    required List<ActuatorMarker> markers,
    double? currentTemp,
  }) {
    // 대표 시각: [now, floorHour(now-3h), floorHour(now-6h), ...]
    // 시(hour) 필드에서 빼면 달력이 정규화해준다 — Duration 뺄셈은 서머타임에
    // 정각을 못 지킨다. 분·초를 안 넘기니 그대로 정각 내림이다.
    final times = <DateTime>[
      now,
      for (var i = 1; i <= pastSlots; i++)
        DateTime(now.year, now.month, now.day, now.hour - stepHours * i),
    ];

    final out = <HourlyEnvSlot>[];
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      // 구간 [lower, upper). 앞(더 최신) 칸과의 중점이 upper, 뒤 칸과의 중점이 lower.
      final upper = i == 0 ? now : _mid(times[i - 1], t);
      final lower = i == times.length - 1
          ? t.subtract(Duration(minutes: stepHours * 30))
          : _mid(t, times[i + 1]);

      final kinds = <MarkerKind>{
        for (final m in markers)
          if (!m.at.isBefore(lower) &&
              (i == 0 ? !m.at.isAfter(upper) : m.at.isBefore(upper)))
            m.kind,
      };

      final temp = i == 0 && currentTemp != null
          ? currentTemp
          : _tempAt(buckets, t, latestOnly: i == 0);

      out.add(HourlyEnvSlot(at: t, isNow: i == 0, temp: temp, kinds: kinds));
    }
    return out;
  }

  static DateTime _mid(DateTime a, DateTime b) =>
      a.add(Duration(microseconds: b.difference(a).inMicroseconds ~/ 2));

  /// [at]에 가장 가까운 버킷의 평균 온도. 허용 오차 밖이면 null.
  /// [latestOnly]면 [at] 이전 것만 본다(지금 칸은 미래 버킷이 없지만 방어).
  ///
  /// ⚠️ 0은 센서 오프라인 센티넬이라 버린다(`project_telemetry_zero_sentinel`).
  static double? _tempAt(List<TelemetryBucket> buckets, DateTime at,
      {required bool latestOnly}) {
    TelemetryBucket? best;
    Duration? bestGap;
    for (final b in buckets) {
      final v = b.tAvg;
      if (v == null || v <= 0) continue;
      if (latestOnly && b.bucket.isAfter(at)) continue;
      final gap = b.bucket.difference(at).abs();
      if (gap > bucketTolerance) continue;
      if (bestGap == null || gap < bestGap) {
        best = b;
        bestGap = gap;
      }
    }
    return best?.tAvg;
  }
}
