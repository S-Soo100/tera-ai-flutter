import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 라이브 영상 두 손가락 확대 중(두 손가락이 닿았거나 1배 초과)인지 — 화면
/// 단위 [scope]별(2026-11-19). true면 그 화면의 세로 스크롤·카메라 넘기기를
/// 잠가 확대·옮기기 손짓을 빼앗기지 않게 한다. 쓰는 쪽은 `WebRtcLiveView`
/// (`zoomLockScope`) 하나뿐이다.
final liveZoomLockProvider =
    StateProvider.autoDispose.family<bool, String>((ref, scope) => false);

/// 화면별 scope 이름.
abstract final class LiveZoomScope {
  static const home = 'home';
  static const cameraTab = 'camera_tab';
  static String fullscreen(String cameraUuid) => 'fullscreen:$cameraUuid';
}
