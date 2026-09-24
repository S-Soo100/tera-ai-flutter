/// 물분무 지속시간.
///
/// 앱은 **"얼마나"만 보낸다.** 펌웨어가 내부 타이머로 자동 OFF하므로 OFF 명령을
/// 따로 보내지 않는다(`APP_TIMER_MIST.md` §1). 앱에서 ON→지연 OFF로 펄스를
/// 흉내내면 앱이 백그라운드로 가는 순간 펌프가 계속 돈다.
///
/// 2026-09-25 사용자 결정으로 5/10초 → **3/6/9초**(기본 3초). 서버 허용값
/// (1/2/3초)과 펌웨어 5초 상한 안에서 한 번에 보낼 수 있는 건 3초뿐이라,
/// 서버가 6000·9000을 지원하기 전까지 6·9초는 **앱이 3초를 2·3번 이어 보낸다**
/// ([kMistServerSupportsLong], `sendMistWith`). 예약은 서버가 실행해서 앱이
/// 이어 붙일 수 없으므로 그때까지 3초만 고를 수 있다([schedulable]).
/// 옛 1/2/3·5/10초 예약·이력은 서버에 그대로 남으므로 [tryFromMilliseconds]가
/// null을 돌려주고, 화면은 저장된 초를 그대로 보여 준다.
///
/// > 기획 이력: PRD §4.2.2 표는 분무를 *"분사 시간(길이) 설정 불가"*로 적었으나,
/// > 백엔드가 `duration_ms`를 제공하면서 2026-08-12 이쪽을 채택했다.
enum MistDuration {
  threeSeconds(3000),
  sixSeconds(6000),
  nineSeconds(9000);

  const MistDuration(this.milliseconds);

  final int milliseconds;

  static const defaultValue = MistDuration.threeSeconds;

  /// 명령 한 번에 싣는 분사 — 서버 허용값·펌웨어 상한 안.
  static const partMilliseconds = 3000;

  int get seconds => milliseconds ~/ 1000;

  /// 이어 보낼 횟수(3초 단위). 서버가 긴 분사를 받으면 1.
  int get parts =>
      kMistServerSupportsLong ? 1 : milliseconds ~/ partMilliseconds;

  /// 명령 한 번의 `commands.payload`. 다른 키는 서버가 받지 않는다.
  Map<String, dynamic> get partPayload => {
        'duration_ms':
            kMistServerSupportsLong ? milliseconds : partMilliseconds
      };

  /// 예약 저장용 payload — 예약은 서버가 한 번에 실행한다.
  Map<String, dynamic> get payload => {'duration_ms': milliseconds};

  /// 예약에 고를 수 있는가. 서버 예약 허용값이 1/2/3초라 6·9초는 서버 지원 뒤.
  bool get schedulable =>
      kMistServerSupportsLong || milliseconds <= partMilliseconds;

  /// 선택지에 있는 값이면 그 값, 아니면 null(옛 1/2/3·5/10초·손상 값).
  static MistDuration? tryFromMilliseconds(int? ms) {
    for (final d in MistDuration.values) {
      if (d.milliseconds == ms) return d;
    }
    return null;
  }
}

/// 서버가 `mist.duration_ms` 6000·9000을 받아 스스로 이어 붙이는가.
/// true로 바꾸면 이어 보내기 없이 명령 한 번으로 보내고, 예약도 6·9초를 연다
/// (이관훈님 회신 대기, 2026-09-25).
const kMistServerSupportsLong = false;
