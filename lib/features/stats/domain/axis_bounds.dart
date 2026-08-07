/// 차트 Y축 경계와 눈금.
///
/// Figma는 온도 `45/40/35/30/25/20`, 습도 `75/70/65/60/55/50`처럼 **5 단위 눈금**
/// 으로 그렸다(`docs/figma-final-design-transcript.md` §3.1). 그 값 자체는 샘플
/// 데이터라, 여기서는 **간격(step)만 따르고 경계는 실제 데이터에서 계산**한다.
///
/// ⚠️ `telemetry_30m`의 **0은 실측이 아니라 센서 오프라인 센티넬**이다
/// (DHT22는 0℃/0%를 낼 수 없다. 메모리 `project_telemetry_zero_sentinel`).
/// 0을 축 계산에 넣으면 축이 0까지 늘어나 실제 곡선이 납작해지므로 여기서 버린다.
class AxisBounds {
  final double min;
  final double max;
  final double step;

  const AxisBounds._({
    required this.min,
    required this.max,
    required this.step,
  });

  /// [values] 전체를 담는 최소 구간을 [step] 배수로 스냅해 만든다.
  ///
  /// 유효한 값(0 초과)이 하나도 없으면 null — 데이터 없이 가짜 축을 그리지 않는다.
  static AxisBounds? forValues(Iterable<double> values, {required double step}) {
    final valid = values.where((v) => v > 0).toList();
    if (valid.isEmpty) return null;

    var lo = valid.reduce((a, b) => a < b ? a : b);
    var hi = valid.reduce((a, b) => a > b ? a : b);

    var min = (lo / step).floorToDouble() * step;
    var max = (hi / step).ceilToDouble() * step;

    // 값이 하나뿐이거나 전부 같은 경계 위에 있으면 폭이 0이 된다.
    // 그대로 두면 normalize가 0으로 나누고, 화면에는 납작한 선이 남는다.
    if (max - min < step) max = min + step;

    return AxisBounds._(min: min, max: max, step: step);
  }

  double get span => max - min;

  /// [min]부터 [max]까지 [step] 간격 눈금 전부.
  List<double> get ticks {
    final out = <double>[];
    for (var v = min; v <= max + 1e-9; v += step) {
      out.add(v);
    }
    return out;
  }

  /// 축 내 위치 비율. min → 0, max → 1.
  double normalize(double value) => (value - min) / span;
}
