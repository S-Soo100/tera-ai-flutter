import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 상수 기능 플래그 — 원격 설정이 아직 없어 값을 바꾸려면 앱을 배포한다.
abstract final class FeatureFlags {
  /// 냉각팬(fan2) 제어. 2026-10-16 사용자 결정으로 껐다가 2026-11-04 사용자
  /// 결정으로 다시 켰다(0.171.0). false면 홈 칸은 "비활성화" + 토스트, 새
  /// 예약·기존 예약 켜기는 막고, **이미 켜져 있으면 끄기만** 허용한다(켜진 팬을
  /// 끌 길이 없으면 사육장이 밤새 식는다). 꺼 둔 동안 사용자가 끈 서버 예약은
  /// 다시 켜도 자동으로 켜지 않는다 — 사용자가 직접 켠다.
  static const bool coolFanEnabled = true;

  /// 온도 보정 새 서버 계약 — 공장 보정 −1.5℃는 서버가 맡고 앱은 **사용자
  /// 보정값만** 주고받는다(보내기 `user_offset_c`, 읽기
  /// `devices.temp_offset_user_c`). 서버 `APP_TEMP_OFFSET_SERVER_BASE_2026-11-05.md`.
  ///
  /// 2026-11-19 켬(0.185.1): 서버 Stage S(11-05 `ce61eca`)·Stage T(11-10, 보드별
  /// 공장 기준 `temp_offset_base_c`) 배포 완료, 서버 `APP_TEMP_OFFSET_2026-11-10.md`
  /// 요청. 옛 계약은 앱 상수 −1.5로 풀어 기준이 다른 보드에서 틀렸다.
  /// 공장 기준(허브 포함)은 서버·펌웨어 몫 — 앱에서 기기별로 가정하지 말 것
  /// (0.184.2 "허브 = 0" 가정은 오판이라 되돌렸다). 되돌릴 땐 false로만 바꾼다
  /// (옛 경로는 그대로 남겨 두었다).
  static const bool tempOffsetUserContract = true;
}

/// 테스트가 덮어쓸 수 있게 provider로 꺼낸다.
final coolFanEnabledProvider =
    Provider<bool>((ref) => FeatureFlags.coolFanEnabled);

/// 테스트가 두 계약을 모두 확인할 수 있게 provider로 꺼낸다.
final tempOffsetUserContractProvider =
    Provider<bool>((ref) => FeatureFlags.tempOffsetUserContract);
