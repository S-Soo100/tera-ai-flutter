/// 물분무 지속시간.
///
/// 앱은 **"얼마나"만 보낸다.** 펌웨어가 내부 타이머로 자동 OFF하므로 OFF 명령을
/// 따로 보내지 않는다(`APP_TIMER_MIST.md` §1). 앱에서 ON→지연 OFF로 펄스를
/// 흉내내면 앱이 백그라운드로 가는 순간 펌프가 계속 돈다.
///
/// 값이 셋뿐인 이유: 서버가 화이트리스트로 검증해 그 외는 400을 준다. 임의 값을
/// 만들 수 있게 두면 거절만 왕복한다.
///
/// 2026-09-23 사용자 결정으로 1/2/3초 → **5/7/10초**(기본 7초). ⚠️ 서버
/// 화이트리스트(1000/2000/3000)와 펌웨어 5초 clamp가 풀려야 실제로 동작한다 —
/// 요청서 `docs/handoffs/2026-09-23-mist-duration-5-7-10-server-request.md`.
/// 옛 1/2/3초 예약·이력은 서버에 그대로 남으므로 [tryFromMilliseconds]가
/// null을 돌려주고, 화면은 저장된 초를 그대로 보여 준다.
///
/// > 기획 이력: PRD §4.2.2 표는 분무를 *"분사 시간(길이) 설정 불가"*로 적었으나,
/// > 백엔드가 `duration_ms`를 제공하면서 2026-08-12 이쪽을 채택했다.
enum MistDuration {
  fiveSeconds(5000),
  sevenSeconds(7000),
  tenSeconds(10000);

  const MistDuration(this.milliseconds);

  final int milliseconds;

  static const defaultValue = MistDuration.sevenSeconds;

  int get seconds => milliseconds ~/ 1000;

  /// `commands.payload`. 다른 키는 서버가 받지 않는다.
  Map<String, dynamic> get payload => {'duration_ms': milliseconds};

  /// 선택지에 있는 값이면 그 값, 아니면 null(옛 1/2/3초·손상 값).
  static MistDuration? tryFromMilliseconds(int? ms) {
    for (final d in MistDuration.values) {
      if (d.milliseconds == ms) return d;
    }
    return null;
  }
}
