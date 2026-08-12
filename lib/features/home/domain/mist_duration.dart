/// 물분무 지속시간.
///
/// 앱은 **"얼마나"만 보낸다.** 펌웨어가 내부 타이머로 자동 OFF하므로 OFF 명령을
/// 따로 보내지 않는다(`APP_TIMER_MIST.md` §1). 앱에서 ON→지연 OFF로 펄스를
/// 흉내내면 앱이 백그라운드로 가는 순간 펌프가 계속 돈다.
///
/// 값이 셋뿐인 이유: 서버가 화이트리스트로 검증해 그 외는 400을 주고, 펌웨어는
/// 5초 상한으로 clamp한다. 임의 값을 만들 수 있게 두면 거절만 왕복한다.
///
/// > 기획 이력: PRD §4.2.2 표는 분무를 *"분사 시간(길이) 설정 불가"*로 적었으나,
/// > 백엔드가 `duration_ms`를 제공하면서 2026-08-12 이쪽을 채택했다.
enum MistDuration {
  oneSecond(1000),
  twoSeconds(2000),
  threeSeconds(3000);

  const MistDuration(this.milliseconds);

  final int milliseconds;

  static const defaultValue = MistDuration.twoSeconds;

  int get seconds => milliseconds ~/ 1000;

  /// `commands.payload`. 다른 키는 서버가 받지 않는다.
  Map<String, dynamic> get payload => {'duration_ms': milliseconds};

  /// 저장된 밀리초를 되돌린다. 모르는 값이면 [defaultValue] —
  /// 값 하나 때문에 분무 버튼이 못 눌리는 상태로 남지 않게 한다.
  static MistDuration fromMilliseconds(int? ms) {
    for (final d in MistDuration.values) {
      if (d.milliseconds == ms) return d;
    }
    return defaultValue;
  }
}
