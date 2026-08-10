import '../../features/my_cage/domain/telemetry_bucket.dart';
import 'axis_bounds.dart';

/// 통계 탭 24시간 차트에 바로 그릴 수 있게 정리된 데이터.
///
/// Figma `온습도 그래프 - 24시`(`docs/figma-final-design-transcript.md` §3.1)를
/// 따른다 — 온도는 **좌축**, 습도는 **우축**, 눈금 간격은 5.
///
/// 두 지표는 단위가 달라 같은 Y축에 못 올린다. 그래서 각자의 [AxisBounds]로
/// **0~1로 정규화해 그리고**, 축 라벨만 각 지표의 실제 눈금을 보여준다.
/// (Figma도 Y축 라벨을 6개 텍스트를 균등 배치한 컬럼으로 그렸다 — 눈금 개수가
/// 좌우로 달라도 각자 자기 범위를 선형으로 나눠 갖기 때문에 올바르다.)
class EnvChartData {
  /// 구간 시작 (x = 0).
  final DateTime from;

  /// 구간 끝 (x = 1).
  final DateTime to;

  /// 온도 축. 유효 데이터가 없으면 null.
  final AxisBounds? tempAxis;

  /// 습도 축. 유효 데이터가 없으면 null.
  final AxisBounds? humidAxis;

  /// 온도 점. x·y 모두 0~1 정규화.
  final List<({double x, double y})> tempPoints;

  /// 습도 점. x·y 모두 0~1 정규화.
  final List<({double x, double y})> humidPoints;

  const EnvChartData({
    required this.from,
    required this.to,
    required this.tempAxis,
    required this.humidAxis,
    required this.tempPoints,
    required this.humidPoints,
  });

  /// 그릴 선이 하나라도 있는가. 점 1개짜리 선은 그려도 보이지 않으므로 제외한다.
  bool get hasData => tempPoints.length > 1 || humidPoints.length > 1;

  // ── 스크러버 조회 (Figma §3.1 "스크러버 툴팁") ──
  //
  // 손가락이 닿은 **곡선 위의 값**을 읽어준다. 원시 x를 그대로 쓰면 선과 점이
  // 어긋나 보이므로(버킷이 30분 간격이라 최대 15분어치 벌어진다), 먼저 가장
  // 가까운 데이터 지점으로 **맞춘 뒤**([snap]) 그 자리의 값을 읽는다.

  /// [x]에 가장 가까운 데이터 지점의 위치. 그릴 점이 없으면 null.
  double? snap(double x) =>
      _nearest(tempPoints.isNotEmpty ? tempPoints : humidPoints, x)?.x;

  /// [x] 자리의 온도(실제 단위 ℃). 없으면 null.
  double? tempAt(double x) => _realValue(_nearest(tempPoints, x), tempAxis);

  /// [x] 자리의 습도(실제 단위 %). 없으면 null.
  double? humidAt(double x) => _realValue(_nearest(humidPoints, x), humidAxis);

  /// [x] 자리의 **정규화 y**(0~1). 스크러버 점을 곡선 위에 얹을 때 쓴다 —
  /// 값이 아니라 위치가 필요한 자리라 되돌리지 않는다.
  double? tempNormAt(double x) => _nearest(tempPoints, x)?.y;

  /// [x] 자리의 정규화 y. 습도 쪽.
  double? humidNormAt(double x) => _nearest(humidPoints, x)?.y;

  /// [x] 자리의 시각.
  DateTime timeAt(double x) {
    final total = to.difference(from).inMicroseconds;
    if (total <= 0) return from;
    return from.add(
      Duration(microseconds: (total * x.clamp(0.0, 1.0)).round()),
    );
  }

  static ({double x, double y})? _nearest(
    List<({double x, double y})> pts,
    double x,
  ) {
    if (pts.isEmpty) return null;
    var best = pts.first;
    var bestGap = (best.x - x).abs();
    for (final p in pts) {
      final gap = (p.x - x).abs();
      if (gap < bestGap) {
        best = p;
        bestGap = gap;
      }
    }
    return best;
  }

  /// 정규화된 y를 사람이 읽는 값으로 되돌린다. 0.42를 보여줘봐야 의미가 없다.
  static double? _realValue(({double x, double y})? p, AxisBounds? axis) =>
      (p == null || axis == null) ? null : axis.min + p.y * axis.span;

  /// 칸 크기의 **하한**. 라벨을 정수로 찍으므로 1보다 작으면 같은 숫자가
  /// 반복된다([AxisBounds.forValues]). 실제 칸 크기는 데이터 폭에 맞춰 정해진다.
  static const double tempStep = 1;
  static const double humidStep = 1;

  /// 버킷 목록에서 조립한다.
  ///
  /// **0 이하 값은 [AxisBounds]와 같은 이유로 버린다** — `telemetry_30m`의 0은
  /// 센서 오프라인 센티넬이지 실측이 아니다. 축뿐 아니라 **점에서도** 빼야
  /// 곡선이 바닥까지 내리꽂히지 않는다.
  factory EnvChartData.from(
    List<TelemetryBucket> buckets, {
    required DateTime from,
    required DateTime to,
  }) {
    final span = to.difference(from).inMicroseconds;

    final temps = <double>[];
    final humids = <double>[];
    for (final b in buckets) {
      final t = b.tAvg;
      final h = b.hAvg;
      if (t != null && t > 0) temps.add(t);
      if (h != null && h > 0) humids.add(h);
    }

    final tempAxis = AxisBounds.forValues(temps, minStep: tempStep);
    final humidAxis = AxisBounds.forValues(humids, minStep: humidStep);

    List<({double x, double y})> points(
      double? Function(TelemetryBucket) pick,
      AxisBounds? axis,
    ) {
      if (axis == null || span <= 0) return const [];
      final out = <({double x, double y})>[];
      for (final b in buckets) {
        final v = pick(b);
        if (v == null || v <= 0) continue;
        final x = b.bucket.difference(from).inMicroseconds / span;
        if (x < 0 || x > 1) continue; // 구간 밖 버킷은 버린다.
        out.add((x: x, y: axis.normalize(v)));
      }
      out.sort((a, b) => a.x.compareTo(b.x));
      return out;
    }

    return EnvChartData(
      from: from,
      to: to,
      tempAxis: tempAxis,
      humidAxis: humidAxis,
      tempPoints: points((b) => b.tAvg, tempAxis),
      humidPoints: points((b) => b.hAvg, humidAxis),
    );
  }
}
