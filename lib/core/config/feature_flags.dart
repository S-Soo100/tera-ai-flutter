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
  /// 꺼 둔 이유: 서버가 아직 배포 전이다(같은 문서 §6 배포 순서 — 서버 먼저).
  /// 먼저 켜면 새 컬럼 조회가 실패하고 명령이 400으로 거절된다. 꺼진 동안은
  /// 옛 계약(합산값 `offset_c`·`temp_offset_c`)을 그대로 쓴다. 서버 문서 맨 위가
  /// '배포 완료'로 바뀐 것을 확인한 뒤 켠다(계획
  /// `docs/superpowers/plans/2026-11-05-temp-offset-user-contract.md` Task 3).
  static const bool tempOffsetUserContract = false;
}

/// 테스트가 덮어쓸 수 있게 provider로 꺼낸다.
final coolFanEnabledProvider =
    Provider<bool>((ref) => FeatureFlags.coolFanEnabled);

/// 테스트가 두 계약을 모두 확인할 수 있게 provider로 꺼낸다.
final tempOffsetUserContractProvider =
    Provider<bool>((ref) => FeatureFlags.tempOffsetUserContract);
