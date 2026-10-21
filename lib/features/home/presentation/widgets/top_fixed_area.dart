import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../my_cage/presentation/webrtc_live_controller.dart';
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
  static const aspectRatio = 369 / 271;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref.watch(currentSetProvider).valueOrNull?.camera;
    if (camera == null) return const SizedBox.shrink();
    // 카메라 오프라인 안내 중엔 확대 버튼을 숨긴다(Figma 1525:10689 메모).
    final offline = ref.watch(webrtcLiveControllerProvider(camera.id)
        .select(WebRtcLiveView.isOfflineNotice));
    return Stack(children: [
      LiveSurface(
          aspectRatio: aspectRatio,
          child: KeyedSubtree(
              key: ValueKey(camera.id),
              child: WebRtcLiveView(
                  key: liveKey, cameraUuid: camera.id, cover: true))),
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
                    onTap: () =>
                        context.push('/crecam/cameras/${camera.id}/live'),
                    child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                            child: FigmaIcon.tinted(FigmaIcons.liveExpand,
                                size: 17, color: AppTheme.liveOnDark)))))),
    ]);
  }
}
