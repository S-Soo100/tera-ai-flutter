import '../../my_cage/domain/telemetry_bucket.dart';

/// 24시간 차트가 그릴 시리즈와 **그 시리즈가 실제로 덮는 시간 구간**.
///
/// 두 가지를 한 곳에서 결정한다.
///
/// 1. **온도·습도가 같은 X축을 쓰도록 버킷을 함께 고른다.**
///    각각 `>0` 필터를 따로 걸면 한쪽만 결측인 버킷에서 리스트 길이가 달라지고,
///    Sparkline은 인덱스를 폭 전체에 균등 배분하므로 두 선이 서로 어긋난다.
///    (0값은 실측이 아니라 센서 오프라인 센티넬이라 온·습도가 함께 0이 된다)
///
/// 2. **마커가 쓸 시간 구간을 데이터 기준으로 돌려준다.**
///    Sparkline은 "가진 데이터"를 폭 100%로 늘려 그린다. 그런데 마커를 차트
///    요청 구간(전날 19:00~현재) 비율로 찍으면, 기기가 구간 일부만 온라인이었을
///    때 선과 마커가 전혀 다른 좌표계를 갖는다. 마커도 [from]~[to](= 실제 버킷
///    범위)로 맞춰야 같은 자리를 가리킨다.
class EnvChartSeries {
  final List<double> temps;
  final List<double> humids;

  /// 시리즈가 덮는 실제 시간 구간. 표본이 2개 미만이면 null.
  final DateTime? from;
  final DateTime? to;

  const EnvChartSeries({
    required this.temps,
    required this.humids,
    required this.from,
    required this.to,
  });

  /// 선을 그릴 만큼(2점 이상) 표본이 있는가.
  bool get hasLine => temps.length >= 2;

  factory EnvChartSeries.from(List<TelemetryBucket> buckets) {
    final valid = [
      for (final b in buckets)
        if ((b.tAvg ?? 0) > 0 && (b.hAvg ?? 0) > 0) b,
    ]..sort((a, b) => a.bucket.compareTo(b.bucket));

    if (valid.length < 2) {
      return const EnvChartSeries(
        temps: [],
        humids: [],
        from: null,
        to: null,
      );
    }
    return EnvChartSeries(
      temps: [for (final b in valid) b.tAvg!],
      humids: [for (final b in valid) b.hAvg!],
      from: valid.first.bucket,
      to: valid.last.bucket,
    );
  }
}
