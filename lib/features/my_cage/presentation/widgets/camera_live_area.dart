import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../home/presentation/home_set_providers.dart';
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
/// - 카메라 페이지: [WebRtcLiveView] cover + 우상단 시계 + 우하단 확장 버튼.
///   **DB `cameras.is_online`으로 게이팅하지 않는다**(2026-09-04) — 그 플래그는
///   stale일 수 있어서, 같은 카메라가 홈(TopFixedArea, 무조건 시도)에선 나오고
///   여기선 "오프라인"으로 갈렸다. 홈과 동일하게 항상 시도하고 연결 실패
///   표시는 스트림 phase를 아는 WebRtcLiveView가 스스로 한다.
/// - 카메라 0대: 접힌 안내 카드 + "카메라 연결하기" → 페어링
class CameraLiveArea extends ConsumerStatefulWidget {
  const CameraLiveArea({super.key});

  static const pageViewKey = Key('crecam_live_pageview');
  static const expandButtonKey = Key('crecam_live_expand');
  static const emptyCardKey = Key('crecam_live_empty');
  static const indicatorKey = Key('crecam_live_indicator');

  /// Figma 실측 369×271.
  static const double aspectRatio = 369 / 271;

  @override
  ConsumerState<CameraLiveArea> createState() => _CameraLiveAreaState();
}

/// 라이브 페이지가 그릴 위젯의 심 — **위젯 테스트 전용 오버라이드 지점**.
/// WebRtcLiveView는 빌드 즉시 실피어 연결을 시작해 테스트를 깨뜨린다
/// (top_fixed_area_test의 "마지막 페이지에 숨기기" 관례를 대체).
final liveViewBuilderProvider = Provider<Widget Function(String cameraUuid)>(
  (_) => (uuid) => WebRtcLiveView(cameraUuid: uuid, cover: true),
);

class _CameraLiveAreaState extends ConsumerState<CameraLiveArea> {
  late final PageController _controller;

  /// 미선택(-1) 해석: **홈이 보고 있는 세트의 카메라**에서 시작 — 홈과 같은
  /// 화면이어야 "탭을 옮겼더니 딴 카메라"가 안 된다(2026-09-04 사용자 제보).
  /// 세트에 캠이 없거나 목록에 없으면 0.
  int _resolveInitial(List<TerraCamera> cameras, int stored) {
    if (cameras.isEmpty) return 0;
    if (stored >= 0) return stored.clamp(0, cameras.length - 1);
    final setCamId =
        ref.read(currentSetProvider).valueOrNull?.camera?.id;
    final i = setCamId == null
        ? -1
        : cameras.indexWhere((c) => c.id == setCamId);
    return i >= 0 ? i : 0;
  }

  @override
  void initState() {
    super.initState();
    // 저장된 인덱스를 그대로 믿지 않는다 — 목록이 줄었을 수 있다
    // (TopFixedArea와 같은 가드).
    final known = ref.read(camerasProvider).valueOrNull ?? const <TerraCamera>[];
    _controller = PageController(
      initialPage:
          _resolveInitial(known, ref.read(selectedCrecamCameraProvider)),
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
    final selected = _resolveInitial(cameras, stored);
    // 미선택(-1) 해석 결과·범위 밖 인덱스는 저장값도 화면값에 맞춘다 —
    // 남겨두면 클립 그리드가 다른 카메라를 보거나(센티넬), 나중에 목록이
    // 늘었을 때 엉뚱한 카메라로 튄다(TopFixedArea 선례).
    if (stored != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedCrecamCameraProvider.notifier).state = selected;
        // initState 시점에 카메라 목록이 아직 로딩이었으면 initialPage가
        // 0으로 굳어 있다 — 해석된 페이지로 점프.
        if (_controller.hasClients &&
            _controller.page?.round() != selected) {
          _controller.jumpToPage(selected);
        }
      });
    }
    final current = cameras[selected];

    final surface = LiveSurface(
      aspectRatio: CameraLiveArea.aspectRatio,
      // 시계는 항상 — 홈(TopFixedArea)과 동일. 연결 실패 문구는 WebRtcLiveView
      // 몫이고, DB is_online은 stale일 수 있어 여기서 판정하지 않는다.
      corner: const LiveClockOverlay(),
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

/// 페이지 하나 — **항상 라이브를 시도한다**(2026-09-04, 클래스 doc 참조).
/// `is_online=false`로 여기서 막으면 stale 플래그 하나로 홈에선 나오는
/// 카메라가 이 탭에서만 "오프라인"이 된다. 연결/실패 표시는
/// [WebRtcLiveView]가 스트림 phase로 스스로 한다.
class _CameraPane extends ConsumerWidget {
  const _CameraPane({required this.camera});

  final TerraCamera camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(liveViewBuilderProvider)(camera.id);
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
