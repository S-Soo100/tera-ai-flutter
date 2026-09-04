import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../home/presentation/widgets/live_clock_overlay.dart';
import '../../domain/terra_camera.dart';
import '../my_cage_providers.dart';
import 'webrtc_live_view.dart';

/// 카메라 탭 라이브 영역 — Figma Camera Home (668:427), 369×271 radius 12.
///
/// 홈 `TopFixedArea`(세트 기준)와 달리 **camerasProvider 전체**를 PageView로
/// 돈다 — 세트에 안 묶인 카메라도 도달 가능해야 한다(구 카메라 그리드의 역할
/// 흡수, 계획서 §2-2). 현재 페이지 인덱스는 [selectedCrecamCameraProvider]로
/// 노출돼 아래 클립 그리드의 기준 카메라가 된다.
///
/// - 온라인 페이지: [WebRtcLiveView] cover + 우상단 시계 + 우하단 확장 버튼
/// - 오프라인 페이지: WebRTC를 시도하지 않고 오프라인 안내만
/// - 카메라 0대: 접힌 안내 카드 + "카메라 연결하기" → 페어링
class CameraLiveArea extends ConsumerStatefulWidget {
  const CameraLiveArea({super.key});

  static const pageViewKey = Key('crecam_live_pageview');
  static const expandButtonKey = Key('crecam_live_expand');
  static const emptyCardKey = Key('crecam_live_empty');
  static const offlinePaneKey = Key('crecam_live_offline_pane');
  static const indicatorKey = Key('crecam_live_indicator');

  /// Figma 실측 369×271.
  static const double aspectRatio = 369 / 271;

  @override
  ConsumerState<CameraLiveArea> createState() => _CameraLiveAreaState();
}

class _CameraLiveAreaState extends ConsumerState<CameraLiveArea> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    // 저장된 인덱스를 그대로 믿지 않는다 — 목록이 줄었을 수 있다
    // (TopFixedArea와 같은 가드).
    final known = ref.read(camerasProvider).valueOrNull?.length ?? 0;
    final saved = ref.read(selectedCrecamCameraProvider);
    _controller = PageController(
      initialPage: known == 0 ? 0 : saved.clamp(0, known - 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(camerasProvider);
    return camerasAsync.when(
      loading: () => const AspectRatio(
        aspectRatio: CameraLiveArea.aspectRatio,
        child: SkeletonLoading(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 12,
        ),
      ),
      error: (err, _) => _ErrorCard(
        onRetry: () => ref.invalidate(camerasProvider),
      ),
      data: (cameras) {
        if (cameras.isEmpty) return const _EmptyCameraCard();
        return _liveSurface(cameras);
      },
    );
  }

  Widget _liveSurface(List<TerraCamera> cameras) {
    final stored = ref.watch(selectedCrecamCameraProvider);
    // 목록이 줄어 저장 인덱스가 범위를 넘었으면 저장값도 화면값에 맞춘다 —
    // 남겨두면 나중에 목록이 늘었을 때 엉뚱한 카메라로 튄다(TopFixedArea 선례).
    if (stored > cameras.length - 1 || stored < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedCrecamCameraProvider.notifier).state =
            stored.clamp(0, cameras.length - 1);
      });
    }
    final selected = stored.clamp(0, cameras.length - 1);
    final current = cameras[selected];

    final surface = LiveSurface(
      aspectRatio: CameraLiveArea.aspectRatio,
      // 시계는 온라인일 때만 — 오프라인 안내 위 "지금 시각"은 라이브로 오독된다.
      corner: current.isOnline ? const LiveClockOverlay() : null,
      footer: cameras.length > 1
          ? _PageDots(
              key: CameraLiveArea.indicatorKey,
              count: cameras.length,
              current: selected,
            )
          : null,
      child: PageView.builder(
        key: CameraLiveArea.pageViewKey,
        controller: _controller,
        itemCount: cameras.length,
        onPageChanged: (i) {
          if (ref.read(selectedCrecamCameraProvider) == i) return;
          ref.read(selectedCrecamCameraProvider.notifier).state = i;
        },
        itemBuilder: (_, i) => _CameraPane(camera: cameras[i]),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Stack(
        children: [
          surface,
          Positioned(
            right: 12,
            bottom: 12,
            child: _ExpandButton(
              key: CameraLiveArea.expandButtonKey,
              cameraId: current.id,
            ),
          ),
        ],
      ),
    );
  }
}

/// 페이지 하나 — 온라인이면 라이브, 오프라인이면 안내(WebRTC 미시도).
class _CameraPane extends StatelessWidget {
  const _CameraPane({required this.camera});

  final TerraCamera camera;

  @override
  Widget build(BuildContext context) {
    if (!camera.isOnline) {
      return LiveSurfaceNotice(
        key: CameraLiveArea.offlinePaneKey,
        title: 'crecam_camera_offline'.tr(),
        detail: camera.name,
      );
    }
    return WebRtcLiveView(cameraUuid: camera.id, cover: true);
  }
}

/// 우하단 확장 — 32pt 원형(black 30%), 카메라 상세로(홈 _ExpandButton 문법).
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/crecam/cameras/$cameraId'),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.zoom_out_map, size: 17.5, color: Colors.white),
        ),
      ),
    );
  }
}

/// 어두운 라이브 면 위 점 인디케이터 — 테마 색은 안 보인다(홈 _PageDots 문법).
class _PageDots extends StatelessWidget {
  const _PageDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

/// 카메라 0대 — 271pt 어두운 면 대신 접힌 안내 카드(계획서 §2-2).
class _EmptyCameraCard extends StatelessWidget {
  const _EmptyCameraCard();

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
      key: CameraLiveArea.emptyCardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glass.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.videocam_outlined, size: 40, color: glass.textTertiary),
          const SizedBox(height: 12),
          Text(
            'my_cage_empty_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 16 * -0.02,
              color: glass.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'my_cage_empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 14 * -0.02,
              color: glass.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/crecam/cameras/pair'),
            icon: const Icon(Icons.add),
            label: Text('my_cage_add_camera'.tr()),
          ),
        ],
      ),
    );
  }
}

/// 카메라 목록 로드 실패 — 빈 화면 대신 재시도를 내놓는다.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glass.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'error_generic'.tr(),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: glass.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
}
