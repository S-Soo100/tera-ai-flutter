/// v4 적정 온습도 범위·온도 보정 도메인 (노션 v4 1-1·1-2, 2026-11-02).
///
/// 대상 종은 크레스티드 게코 하나다. 이 파일은 **설정 가능 범위**와 값 변환만
/// 다룬다 — 이탈 판정(15℃ 미만 경고 등)은 서버만 하고 앱은 복제하지 않는다.
///
/// `home`이 아니라 `shared/domain`에 두는 이유: `my_cage/domain/device_settings.dart`
/// 가 [EnvRange.fromSettings]를 쓴다(feature 간 역참조 방지).
///
/// 부동소수 비교·스텝 계산은 모두 **0.1 단위 정수**(`(v * 10).round()`)로 한다.
/// 0.5를 28번 더하면 29.000000000000004가 되는 식의 오차가 스텝 판정과 버튼
/// 활성 조건을 흔들지 않게 하려는 것이다.
library;

import 'num_format.dart';

/// `v`를 0.1 단위 정수로. 18.3 → 183.
int _tenths(double v) => (v * 10).round();

/// `v`가 0.1 단위 위에 있는가(누적 오차는 허용).
bool _onTenths(double v) => ((v * 10) - _tenths(v)).abs() < 1e-6;

/// 설정 가능 범위와 스텝. 범위는 경계 포함(`lower ≤ v ≤ upper`).
class EnvRangeRule {
  final double lower;
  final double upper;
  final double step;

  const EnvRangeRule(this.lower, this.upper, this.step);

  /// 온도: 15℃ 이상 29℃ 이하, 0.5℃ 단위.
  static const EnvRangeRule temp = EnvRangeRule(15, 29, 0.5);

  /// 습도: 35% 이상 85% 이하, 5% 단위.
  static const EnvRangeRule humid = EnvRangeRule(35, 85, 5);

  int get _stepT => _tenths(step);
  int get _lowerT => _tenths(lower);
  int get _upperT => _tenths(upper);

  int _snapT(double v) {
    final steps = ((v * 10) / _stepT).round();
    return (steps * _stepT).clamp(_lowerT, _upperT);
  }

  /// 가장 가까운 스텝으로 맞추고 범위 안으로 clamp.
  double snap(double v) => _snapT(v) / 10;

  /// 스텝 배수이고 범위 안인가.
  bool _accepts(double v) {
    if (!_onTenths(v)) return false;
    final t = _tenths(v);
    return t >= _lowerT && t <= _upperT && t % _stepT == 0;
  }

  /// 맞춘 값 기준으로 한 칸 내릴 수 있는가.
  bool canDecrease(double v) => _snapT(v) > _lowerT;

  /// 맞춘 값 기준으로 한 칸 올릴 수 있는가.
  bool canIncrease(double v) => _snapT(v) < _upperT;

  /// 한 칸 내림. 이미 하한이면 하한 그대로.
  double decrease(double v) =>
      (_snapT(v) - _stepT).clamp(_lowerT, _upperT) / 10;

  /// 한 칸 올림. 이미 상한이면 상한 그대로.
  double increase(double v) =>
      (_snapT(v) + _stepT).clamp(_lowerT, _upperT) / 10;

  // ── 적정 범위 스테퍼(MIN < MAX를 깨지 않는 이동만) ──

  /// 최소 −: 하한 위에서만.
  bool canDecreaseMin(EnvRange r) => canDecrease(r.min);

  /// 최소 +: 한 칸 올려도 최대보다 작을 때만.
  bool canIncreaseMin(EnvRange r) =>
      canIncrease(r.min) && _tenths(increase(r.min)) < _tenths(r.max);

  /// 최대 −: 한 칸 내려도 최소보다 클 때만.
  bool canDecreaseMax(EnvRange r) =>
      canDecrease(r.max) && _tenths(decrease(r.max)) > _tenths(r.min);

  /// 최대 +: 상한 아래에서만.
  bool canIncreaseMax(EnvRange r) => canIncrease(r.max);
}

/// 적정 범위 MIN~MAX. 적정 = `min ≤ 값 ≤ max`(경계 포함).
class EnvRange {
  final double min;
  final double max;

  const EnvRange(this.min, this.max);

  /// 온도 디폴트 18~27℃ — 서버 판정 디폴트와 같아야 한다(2026-11-04 사용자
  /// 결정으로 상한 26→27, 서버도 같은 날 변경 요청. 26에선 고온 주의가 너무
  /// 쉽게 울렸다).
  static const EnvRange tempDefault = EnvRange(18, 27);

  /// 습도 디폴트 40~80%.
  static const EnvRange humidDefault = EnvRange(40, 80);

  /// 저장 가능한 값인가 — 범위 안·스텝 배수·`min < max`.
  bool isValidFor(EnvRangeRule rule) =>
      rule._accepts(min) && rule._accepts(max) && _tenths(min) < _tenths(max);

  /// 서버 `device_settings.target_*_min/max`를 화면용 범위로.
  ///
  /// 순서: ① min·max 각각 null이면 [fallback]의 같은 쪽 ② [EnvRangeRule.snap]
  /// ③ 그래도 `min >= max`면 **둘 다** [fallback]. 서버 N2(범위 검증) 전에는
  /// 콘솔 등으로 범위 밖·스텝 밖 값이 들어올 수 있어 읽을 때 맞춘다.
  static EnvRange fromSettings(
    double? min,
    double? max,
    EnvRangeRule rule,
    EnvRange fallback,
  ) {
    final lo = rule.snap(min ?? fallback.min);
    final hi = rule.snap(max ?? fallback.max);
    if (_tenths(lo) >= _tenths(hi)) return fallback;
    return EnvRange(lo, hi);
  }

  @override
  bool operator ==(Object other) =>
      other is EnvRange &&
      _tenths(other.min) == _tenths(min) &&
      _tenths(other.max) == _tenths(max);

  @override
  int get hashCode => Object.hash(_tenths(min), _tenths(max));

  @override
  String toString() => 'EnvRange($min, $max)';
}

/// 온도 보정 — [value]는 **사용자 보정값**(측정값에 더하는 수, 끔 = 0).
///
/// 기기 값(`devices.temp_offset_c`·명령 `offset_c`) = 공장 보정 −1.5 + 사용자
/// 보정(서버 회신 2026-11-02 §1.2 — D1 임시 규칙 "끔 = 0"을 대체). 다른 곳은
/// [value]를 기기 값으로 직접 쓰지 말고 반드시 [fromDevice]·[toDeviceValue]를
/// 거친다. 끔에 0을 보내면 보드 발열이 실려 온도가 약 1.5℃ 높게 올라온다.
class TempOffset {
  final double value;

  const TempOffset(this.value);

  /// 편집기 크기 상한 4.0℃, 0.1℃ 단위(Figma S24). 기기 명령 허용은 ±10.0.
  static const double maxMagnitude = 4.0;
  static const double step = 0.1;

  bool get isOff => value == 0;
  bool get isSubtract => value < 0;
  double get magnitude => value.abs();

  /// 기기 값이 편집기 범위(±4.0)를 넘는가 — 콘솔 입력 등. 편집기는 4.0으로
  /// 맞춰 시작한다(Task 4).
  bool get outOfEditorRange => _tenths(magnitude) > _tenths(maxMagnitude);

  /// 편집기 입력(방향 + 크기)으로 만든다. 크기는 0.1~4.0이고 0.1 단위여야
  /// 한다 — 아니면 [ArgumentError](기기로 나갈 값이라 조용히 맞추지 않는다).
  factory TempOffset.of({required bool subtract, required double magnitude}) {
    if (!_onTenths(magnitude)) {
      throw ArgumentError.value(
          magnitude, 'magnitude', 'not a multiple of 0.1');
    }
    final t = _tenths(magnitude);
    if (t < _tenths(step) || t > _tenths(maxMagnitude)) {
      throw ArgumentError.value(magnitude, 'magnitude', 'outside 0.1..4.0');
    }
    return TempOffset((subtract ? -t : t) / 10);
  }

  /// 공장 보정(보드 발열 상쇄) — 펌웨어 빌드 기본값. 기기에는 값이 하나뿐이라
  /// (NVS가 기본값을 **덮어쓴다**) "공장 보정 + 사용자 보정"을 합쳐 보낸다
  /// (서버 회신 2026-11-02 §1.2). 보드별로 달라지면 서버가 `capabilities`로
  /// 알려 주기로 했다 — 그때 이 상수를 기기별 값으로 바꾼다.
  static const double factoryDeviceValue = -1.5;

  /// 기기가 보고한 `devices.temp_offset_c` → 사용자 보정값(공장 보정을 뺀 값).
  /// throw 없음(편집기 밖은 [outOfEditorRange]로 드러낸다). 0.1 단위로 맞춘다.
  static TempOffset fromDevice(double deviceValue) =>
      TempOffset(_tenths(deviceValue - factoryDeviceValue) / 10);

  /// 기기 명령 `set_temp_offset`의 `offset_c` — 끔(0)이면 공장 보정 −1.5.
  /// 편집기 끝값(±4)이면 −5.5 ~ +2.5로 서버 허용 ±10 안이다.
  double toDeviceValue() => _tenths(value + factoryDeviceValue) / 10;

  /// 화면의 "현재 측정 온도" — 기기가 보낸 보정 후 온도(`t_a`)에서 사용자 보정만
  /// 걷어낸 값(공장 보정은 남긴다: 보정 꺼짐일 때 홈에 보이는 값과 같다).
  static double measuredFrom(double reportedTemp, double deviceOffset) =>
      reportedTemp - fromDevice(deviceOffset).value;

  /// "+1" / "-2" / "+0.5" — 온습도 설정의 "측정값 {}℃"(Figma S35·S06).
  String get signedLabel => value > 0
      ? '+${formatCompact(value)}'
      : formatCompact(value);

  /// 원래 측정값에 이 보정을 적용한 값.
  double apply(double raw) => raw + value;
}
