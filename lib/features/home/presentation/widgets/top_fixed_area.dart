import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../my_cage/presentation/webrtc_live_controller.dart';
import '../../../my_cage/presentation/widgets/live_notice_bar.dart';
import '../../../my_cage/presentation/widgets/weak_signal_notice_prompt.dart';
import '../../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../home_set_providers.dart';

/// Only the selected enclosure camera occupies this surface.
/// An enclosure without a camera has no live surface or reserved gap.
class TopFixedArea extends ConsumerWidget {
  const TopFixedArea({super.key});
  static const pageViewKey = Key('top_fixed_pageview');
  static const liveKey = Key('top_fixed_live');
  static const noCameraPaneKey = Key('top_fixed_no_camera_pane');
  static const noCameraLineKey = Key('top_fixed_no_camera_line');
  static const indicatorKey = Key('top_fixed_indicator');
  static const expandButtonKey = Key('top_fixed_expand');
  static const liveTapKey = Key('top_fixed_live_tap');
  static const aspectRatio = 369 / 271;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref.watch(currentSetProvider).valueOrNull?.camera;
    if (camera == null) return const SizedBox.shrink();
    // 카메라 오프라인 안내 중엔 확대 버튼을 숨긴다(Figma 1525:10689 메모).
    final offline = ref.watch(webrtcLiveControllerProvider(camera.id)
        .select(WebRtcLiveView.isOfflineNotice));
    void openLive() => context.push('/crecam/cameras/${camera.id}/live');
    return Stack(children: [
      // 영상을 탭해도 확대 버튼과 같은 확대 라이브 화면으로 간다 — 두 손가락
      // 확대는 거기서 한다(홈에서 확대하면 스크롤이 멈춰 불편, 2026-11-19 사용자
      // 결정). 확대 버튼이 숨는 오프라인 안내 중엔 가지 않는다. 재시도 같은 안의
      // 버튼은 그 버튼이 먼저 받는다.
      GestureDetector(
          key: liveTapKey,
          // 영상 텍스처는 탭을 받지 않는다 — 면 전체를 탭 영역으로.
          behavior: HitTestBehavior.opaque,
          onTap: offline ? null : openLive,
          child: LiveSurface(
              aspectRatio: aspectRatio,
              child: KeyedSubtree(
                  key: ValueKey(camera.id),
                  child: WebRtcLiveView(
                      key: liveKey, cameraUuid: camera.id, cover: true)))),
      if (!offline)
        Positioned(
            right: 20,
            bottom: 12,
            child: Material(
                key: expandButtonKey,
                color: AppTheme.liveScrim,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: openLive,
                    child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                            child: FigmaIcon.tinted(FigmaIcons.liveExpand,
                                size: 17, color: AppTheme.liveOnDark)))))),
      // 렌즈 초점 안내 — 카메라 탭과 같다(Figma 1813:8265 "홈화면에도 동일").
      Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: LiveNoticeBar(
              cameraId: camera.id, deviceId: camera.cameraId)),
      // 네트워크 신호 약함 모달(Figma 2020:11196) — 자리는 차지하지 않는다.
      WeakSignalNoticePrompt(
          cameraId: camera.id,
          deviceId: camera.cameraId),
    ]);
  }
}
