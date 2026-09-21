/// 활동 시간 막대 그래프의 세로 축.
///
/// Figma 원본은 3시간 축으로 그려져 있지만 그건 그 샘플 데이터에 맞는 눈금일
/// 뿐이다 — **가변 축**이 맞다. 3시간을 하한으로 못박아 두면 하루 10분짜리
/// 주(週)가 막대 7개 전부 바닥에 붙은 점으로 그려진다(2026-09-21 신고).
///
/// 온습도 축([AxisBounds])과 같은 발상이되 칸 크기 후보가 다르다. 1·2·5 계열을
/// 시간에 그대로 쓰면 0.2h(12분)·7.5분처럼 시계로 못 읽는 칸이 나오므로,
/// **사람이 시계로 읽는 단위**만 후보로 둔다.
class ActivityAxis {
  const ActivityAxis._({required this.maxSeconds, required this.stepSeconds});

  /// 축 꼭대기(초). 축은 언제나 0에서 시작한다 — 막대 그래프라 바닥을
  /// 잘라내면 길이 비교가 거짓말이 된다.
  final double maxSeconds;

  /// 눈금 한 칸(초).
  final double stepSeconds;

  /// 눈금 칸 수. 라벨은 하나 더 많다(원본 격자 7줄).
  static const int divisions = 6;

  /// 칸 크기 후보(초) — 축 꼭대기는 이 값의 6배다.
  /// 1·2·5·10·15·30분, 1·2·4시간 → 6·12·30·60·90분, 3·6·12·24시간.
  static const List<double> _steps = [
    60, // 6분
    120, // 12분
    300, // 30분
    600, // 1시간
    900, // 1시간 30분
    1800, // 3시간
    3600, // 6시간
    7200, // 12시간
    14400, // 24시간
  ];

  /// 측정값이 하나도 없을 때의 축. 가짜로 좁히지도, 3시간으로 늘리지도 않는다.
  static const double _emptyStep = 600;

  /// [peakSeconds]를 담는 가장 작은 축.
  factory ActivityAxis.forPeak(double peakSeconds) {
    if (!(peakSeconds > 0)) {
      return const ActivityAxis._(
          maxSeconds: _emptyStep * divisions, stepSeconds: _emptyStep);
    }
    for (final step in _steps) {
      if (step * divisions >= peakSeconds) {
        return ActivityAxis._(
            maxSeconds: step * divisions, stepSeconds: step);
      }
    }
    // 하루를 넘는 값은 나올 수 없지만(창이 24시간), 그래도 자르지 않는다.
    final step = (peakSeconds / divisions / 3600).ceilToDouble() * 3600;
    return ActivityAxis._(maxSeconds: step * divisions, stepSeconds: step);
  }

  /// 0부터 [maxSeconds]까지 [stepSeconds] 간격. 항상 [divisions]+1개.
  List<double> get ticks =>
      [for (var i = 0; i <= divisions; i++) stepSeconds * i];

  /// 라벨을 분으로 읽을지. 90분 이하에서 시간으로 쓰면 `0.3h`처럼 읽을 수
  /// 없는 숫자가 된다.
  bool get inMinutes => stepSeconds < 1800;
}
