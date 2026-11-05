import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../my_cage/presentation/supabase_module_providers.dart';
import '../domain/auto_env.dart';

/// 자동 환기·분무 토글을 보일지 — [kAutoEnvReleased]. 상수를 직접 읽지 않고
/// provider로 두는 건 테스트에서 켠 화면을 override로 그려 보려는 것이다.
final autoEnvReleasedProvider = Provider<bool>((_) => kAutoEnvReleased);

/// 기기 한 대의 서버 자동 환경 제어 상태(`devices.auto_env_state`, 계약 C3).
///
/// 새 Realtime 채널을 열지 않고 [deviceLinkStatusProvider]가 이미 받는 같은
/// `devices` 행에서 [AutoEnvState]만 `select`한다 — 3초마다 오는 생존 신호로
/// 다시 그려지지 않게. 조회 중·에러·해제(null)는 [AutoEnvState.none]이다
/// (자동이 켠 팬이 있다고 단정하지 않는다).
final autoEnvStateProvider =
    Provider.autoDispose.family<AutoEnvState, String>((ref, deviceId) {
  return ref.watch(deviceLinkStatusProvider(deviceId)
      .select((s) => s.valueOrNull?.autoEnv ?? AutoEnvState.none));
});
