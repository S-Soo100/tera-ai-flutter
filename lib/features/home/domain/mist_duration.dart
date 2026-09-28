/// 물분무 지속시간.
///
/// 앱은 **"얼마나"만 보낸다.** 펌웨어가 내부 타이머로 자동 OFF하므로 OFF 명령을
/// 따로 보내지 않는다(`APP_TIMER_MIST.md` §1). 앱에서 ON→지연 OFF로 펄스를
/// 흉내내면 앱이 백그라운드로 가는 순간 펌프가 계속 돈다.
///
/// 2026-09-25 사용자 결정으로 5/10초 → 3/6/9초, **2026-09-29 3/5/9초**(기본 3초,
/// 실기기에서 이어 보낸 6·9초가 3초만 뿌려져 명령 한 번 3000/5000/9000으로). 처음엔 서버 허용값
/// 밖이라 6·9초를 **앱이 3초씩 이어 보냈다**. 2026-09-28 서버 확인(terra-server
/// `dispatcher.py` 분할 — 9/23부터 운영): 즉시 분무(commands 직결)는 허용값 검사가
/// 없고, 기기 상한(`capabilities.mist_max_ms`, 구 펌웨어 5000)을 넘으면 서버가
/// 상한만큼 먼저 보내고 나머지를 1.5초 뒤 `source='timer'` 후속으로 보낸다(9초 =
/// 5+4, 신 펌웨어 30초 상한은 한 번에). 그래서 즉시 분무는 **명령 한 번**
/// ([kMistServerSupportsLong]). 예약은 REST 검증을 거치는데 1~20초 범위(`e2eba29`)가
/// 운영 배포 전이라 3초만 고른다([kMistSchedulesSupportLong], [schedulable]).
/// 옛 1/2/3·5/10초 예약·이력은 서버에 그대로 남으므로 [tryFromMilliseconds]가
/// null을 돌려주고, 화면은 저장된 초를 그대로 보여 준다.
///
/// > 기획 이력: PRD §4.2.2 표는 분무를 *"분사 시간(길이) 설정 불가"*로 적었으나,
/// > 백엔드가 `duration_ms`를 제공하면서 2026-08-12 이쪽을 채택했다.
enum MistDuration {
  threeSeconds(3000),
  fiveSeconds(5000),
  nineSeconds(9000);

  const MistDuration(this.milliseconds);

  final int milliseconds;

  static const defaultValue = MistDuration.threeSeconds;

  /// 명령 한 번에 싣는 분사 — 서버 허용값·펌웨어 상한 안.
  static const partMilliseconds = 3000;

  int get seconds => milliseconds ~/ 1000;

  /// 이어 보낼 횟수(3초 단위, 올림). 서버가 나눠 보내면 1. 되돌림용 경로라
  /// 5초는 3초×2(6초)가 된다 — 쓰지 않는다.
  int get parts => kMistServerSupportsLong
      ? 1
      : (milliseconds + partMilliseconds - 1) ~/ partMilliseconds;

  /// 명령 한 번의 `commands.payload`. 다른 키는 서버가 받지 않는다.
  Map<String, dynamic> get partPayload => {
        'duration_ms':
            kMistServerSupportsLong ? milliseconds : partMilliseconds
      };

  /// 예약 저장용 payload — 예약은 서버가 한 번에 실행한다.
  Map<String, dynamic> get payload => {'duration_ms': milliseconds};

  /// 예약에 고를 수 있는가. 서버 예약의 옛 허용값(1/2/3/5/7/10초)에 있는
  /// 3·5초는 지금도 되고, 9초는 1~20초 범위 검증(`e2eba29`)이 운영에 배포된
  /// 뒤다([kMistSchedulesSupportLong]).
  bool get schedulable =>
      kMistSchedulesSupportLong || _legacySchedulable.contains(milliseconds);

  static const _legacySchedulable = {1000, 2000, 3000, 5000, 7000, 10000};

  /// 선택지에 있는 값이면 그 값, 아니면 null(옛 1/2/3·5/10초·손상 값).
  static MistDuration? tryFromMilliseconds(int? ms) {
    for (final d in MistDuration.values) {
      if (d.milliseconds == ms) return d;
    }
    return null;
  }
}

/// 즉시 분무 6000·9000을 명령 한 번으로 보내는가 — 서버가 기기 상한에 맞춰
/// 나눠 보낸다(terra-server `backend/mqtt/dispatcher.py` 2.5단계, 2026-09-28 확인).
/// false면 앱이 3초를 이어 보낸다(`sendMistWith`, 되돌릴 때를 위해 남겨 둔다).
const kMistServerSupportsLong = true;

/// 예약에서 6·9초를 고를 수 있는가. 서버 예약 검증이 1~20초 범위로 바뀐
/// `e2eba29`(2026-09-28)의 **운영 배포가 확인되면** true로 바꾼다 — 배포 전엔
/// 6000·9000 예약이 400이다(terra-server `docs/APP_MIST_DURATION_2026-09-28.md` §4).
const kMistSchedulesSupportLong = false;
