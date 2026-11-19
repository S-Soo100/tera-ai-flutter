import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';

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

/// 카메라 오프라인 안내(Figma 1525:10689) 상태로 고정한 컨트롤러 — 시그널링 없음.
class OfflineLiveController extends WebRtcLiveController {
  OfflineLiveController(super.ref, super.cameraUuid) {
    state = const WebRtcLiveState(
      phase: WebRtcLivePhase.failed,
      errorKey: 'crecam_live_error_camera_offline',
    );
  }
}

/// 영상이 나오는 중으로 고정한 컨트롤러 — 시그널링 없음, 가짜 렌더러.
/// 두 손가락 확대처럼 재생 중에만 있는 면을 시험할 때 쓴다.
class StreamingLiveController extends WebRtcLiveController {
  StreamingLiveController(super.ref, super.cameraUuid) {
    state = WebRtcLiveState(
        phase: WebRtcLivePhase.streaming, renderer: FakeLiveRenderer());
  }
}

class FakeLiveRenderer extends RTCVideoRenderer {
  @override
  Future<void> initialize() async {}
  @override
  set srcObject(MediaStream? stream) {}
  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

/// 라이브 면 가운데서 두 손가락으로 벌린다.
Future<void> pinchOutAt(WidgetTester tester, Finder target) async {
  final c = tester.getCenter(target);
  final a = await tester.startGesture(c - const Offset(20, 0), pointer: 1);
  final b = await tester.startGesture(c + const Offset(20, 0), pointer: 2);
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await a.moveBy(const Offset(-10, 0));
    await b.moveBy(const Offset(10, 0));
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}

/// 두 번 탭.
Future<void> doubleTapAt(WidgetTester tester, Finder target) async {
  final c = tester.getCenter(target);
  await tester.tapAt(c);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(c);
  await tester.pumpAndSettle();
}
