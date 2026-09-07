import 'package:vivnanaut/features/my_cage/presentation/webrtc_live_controller.dart';

/// 위젯 테스트용 라이브 컨트롤러 — **시그널링을 시작하지 않는다**(A2,
/// 2026-09-07: 생성자 부작용이 provider의 `startConnection()`으로 분리되어
/// 가능해졌다).
///
/// phase를 `failed`로 시드하는 이유: connectingConfig의 Shimmer 스켈레톤은
/// 무한 애니메이션이라 `pumpAndSettle`이 영영 안 끝난다. failed 화면은
/// 정적(문구+재시도 버튼)이고, 테스트에서 재시도를 누르지 않는 한 아무
/// 네트워크도 타지 않는다.
class InertLiveController extends WebRtcLiveController {
  InertLiveController(super.ref, super.cameraUuid) {
    state = const WebRtcLiveState(
      phase: WebRtcLivePhase.failed,
      errorKey: 'test_live_inert',
    );
  }
}
