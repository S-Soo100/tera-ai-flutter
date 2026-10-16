import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 상수 기능 플래그 — 원격 설정이 아직 없어 값을 바꾸려면 앱을 배포한다.
abstract final class FeatureFlags {
  /// 냉각팬(fan2) 제어. 2026-10-16 사용자 결정으로 당분간 끈다 — 홈 칸은
  /// "비활성화" + 토스트, 새 예약·기존 예약 켜기는 막고, **이미 켜져 있으면
  /// 끄기만** 허용한다(켜진 팬을 끌 길이 없으면 사육장이 밤새 식는다).
  /// 다시 켤 땐 true로 바꾸고, 꺼 둔 서버 예약은 사용자가 직접 켜게 둔다.
  static const bool coolFanEnabled = false;
}

/// 테스트가 덮어쓸 수 있게 provider로 꺼낸다.
final coolFanEnabledProvider =
    Provider<bool>((ref) => FeatureFlags.coolFanEnabled);
