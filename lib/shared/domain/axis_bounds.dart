/// 차트 Y축 경계와 눈금.
///
/// Figma는 온도 `45/40/35/30/25/20`, 습도 `75/70/65/60/55/50`으로 그렸다
/// (`docs/figma-final-design-transcript.md` §3.1). 거기서 가져올 불변식은
/// **라벨이 6개**라는 것이지 "5 단위"가 아니다 — 5는 그 샘플 데이터에 맞는
/// 칸 크기였을 뿐이다.
///
/// 그래서 여기서는 **개수를 고정하고 칸 크기를 데이터에 맞춘다.**
/// 개수를 데이터에 맡기면 격자선 6줄과 라벨 수가 어긋나 축을 못 읽고(실기기에서
/// 라벨 3개가 위쪽에 뭉쳤다), 칸 크기를 5로 못박으면 23~26℃ 같은 좁은 구간이
/// 10~35 축에 그려져 곡선이 납작해진다.
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

  /// 눈금 칸 수. 라벨은 이보다 하나 많다(6개).
  static const int divisions = 5;

  /// 칸 크기 후보의 가수(假數). 1·2·5의 10의 거듭제곱 배만 쓴다 —
  /// 3이나 7 단위 눈금은 사람이 암산으로 못 읽는다.
  static const List<double> _mantissas = [1, 2, 5];

  /// [values] 전체를 담는 구간. 눈금은 **항상 [divisions]+1개**.
  ///
  /// [minStep]은 칸 크기의 하한이다. 1보다 작아지면 라벨에 소수점이 붙는다
  /// ([decimals]) — 안 붙이면 `28° 28° 29°`처럼 같은 숫자가 반복된다.
  ///
  /// 하한을 1로 두면 축이 최소 5단위 폭이 되어, 0.5℃짜리 변화가 세로 10%만
  /// 쓰고 직선처럼 눕는다. 그래서 0.2까지 내려간다.
  ///
  /// 유효한 값(0 초과)이 하나도 없으면 null — 데이터 없이 가짜 축을 그리지 않는다.
  static AxisBounds? forValues(
    Iterable<double> values, {
    double minStep = 0.2,
  }) {
    final valid = values.where((v) => v > 0).toList();
    if (valid.isEmpty) return null;

    final lo = valid.reduce((a, b) => a < b ? a : b);
    final hi = valid.reduce((a, b) => a > b ? a : b);

    final s = _pickStep(lo: lo, hi: hi, minStep: minStep);
    var min = (lo / s).floorToDouble() * s;
    var max = (hi / s).ceilToDouble() * s;

    // 모자란 칸은 **여유가 적은 쪽부터** 채운다. 한쪽으로만 넓히면 곡선이
    // 위나 아래 모서리에 붙어 그려진다.
    for (var n = ((max - min) / s).round(); n < divisions; n++) {
      if (lo - min <= max - hi) {
        min -= s;
      } else {
        max += s;
      }
    }

    return AxisBounds._(min: min, max: max, step: s);
  }

  /// 데이터를 [divisions]칸 안에 담는 가장 작은 "읽을 만한" 칸 크기.
  ///
  /// 스냅(내림·올림) 뒤에 칸이 하나 더 생길 수 있으므로 **스냅한 결과로**
  /// 판정한다 — 폭만 보고 고르면 경계에 걸칠 때 칸이 넘친다.
  static double _pickStep({
    required double lo,
    required double hi,
    required double minStep,
  }) {
    // 후보는 **[minStep] 바로 위**부터 훑어야 한다. 1에서만 출발하면 하한이
    // 1보다 작아도 0.2·0.5 같은 칸을 아예 못 만들어, 좁은 구간이 5단위 축에
    // 그려진 채 그대로 눕는다.
    var mag = 1.0;
    while (mag > minStep) {
      mag /= 10;
    }
    while (mag * _mantissas.last < minStep) {
      mag *= 10;
    }
    for (var guard = 0; guard < 32; guard++) {
      for (final m in _mantissas) {
        final s = m * mag;
        if (s < minStep - 1e-9) continue;
        final n = ((hi / s).ceilToDouble() - (lo / s).floorToDouble()).round();
        if (n <= divisions) return s;
      }
      mag *= 10;
    }
    // 여기까지 올 일은 없다(칸이 커지면 반드시 담긴다). 안전값.
    return minStep;
  }

  double get span => max - min;

  /// 라벨에 필요한 소수 자릿수.
  ///
  /// 칸이 1보다 작으면 정수로 찍었을 때 같은 숫자가 반복된다. 하한이 0.2라
  /// **한 자리를 넘길 일은 없다** — 더 내려가면 라벨이 축 컬럼을 넘친다.
  int get decimals => step >= 1 ? 0 : 1;

  /// [min]부터 [max]까지 [step] 간격 눈금 전부. 항상 [divisions]+1개.
  List<double> get ticks {
    final out = <double>[];
    for (var i = 0; i <= divisions; i++) {
      out.add(min + step * i);
    }
    return out;
  }

  /// 축 내 위치 비율. min → 0, max → 1.
  double normalize(double value) => (value - min) / span;
}
