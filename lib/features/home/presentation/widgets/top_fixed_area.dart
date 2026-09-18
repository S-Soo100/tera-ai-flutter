import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/live_surface.dart';
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
  static const aspectRatio = 369 / 271;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref.watch(currentSetProvider).valueOrNull?.camera;
    if (camera == null) return const SizedBox.shrink();
    return Stack(children: [
      LiveSurface(
          aspectRatio: aspectRatio,
          child: KeyedSubtree(
              key: ValueKey(camera.id),
              child: WebRtcLiveView(
                  key: liveKey, cameraUuid: camera.id, cover: true))),
      Positioned(
          right: 20,
          bottom: 12,
          child: Material(
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
