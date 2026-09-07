import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../home/domain/enclosure_set.dart';
import '../../../home/presentation/home_set_providers.dart';
import '../../../home/presentation/widgets/live_clock_overlay.dart';
import '../../domain/terra_camera.dart';
import '../my_cage_providers.dart';
import 'live_connection_badge.dart';
import 'webrtc_live_view.dart';

/// 카메라 탭 라이브 영역 — Figma Camera Home (668:427), 369×271 radius 12.
///
/// 홈 `TopFixedArea`(세트 기준)와 달리 **카메라 전체**를 PageView로 돈다 —
/// 세트에 안 묶인 카메라도 도달 가능해야 한다(구 카메라 그리드의 역할 흡수,
/// 계획서 §2-2). 단, 순서는 [orderCamerasBySets]로 **홈 세트 순서를 따른다**
/// (2026-09-07 사용자 제보 — 탭을 오가면 슬라이드 순서가 달라 보였다).
/// 현재 카메라 id는 [selectedCrecamCameraProvider]로 노출돼 아래 클립
/// 그리드의 기준 카메라가 된다.
///
/// **홈과 현재 슬라이드 양방향 동기화**(2026-09-07):
/// - 여기서 스와이프 → 그 카메라가 속한 세트로 [selectedSetIndexProvider]를
///   갱신(홈 TopFixedArea의 기존 listen이 페이지를 따라 움직인다)
/// - 홈에서 세트 변경 → [currentSetProvider] listen으로 이 PageView가 따라간다
///   (세트의 카메라가 **실제로 바뀐** 전환에만 반응 — 단순 재조회 재방출에
///   반응하면 세트 밖 카메라를 보던 사용자를 홈 카메라로 끌어온다)
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

// liveViewBuilderProvider(테스트 심)는 2026-09-07 제거 — WebRtcLiveController
// 생성자가 무해해져(startConnection 분리) 테스트는
// `webrtcLiveControllerProvider`를 시작 없는 컨트롤러로 오버라이드한다.

/// 카메라 탭 슬라이드 순서 — **홈(세트 PageView)과 같은 순서**로 돌아야 탭을
/// 오가도 "몇 번째 카메라"가 안 바뀐다(2026-09-07 사용자 제보). 세트에 물린
/// 카메라를 세트 순서대로 먼저, 세트 밖 카메라는 뒤에 원래 순서대로 붙인다.
List<TerraCamera> orderCamerasBySets(
    List<TerraCamera> cameras, List<EnclosureSet> sets) {
  final byId = {for (final c in cameras) c.id: c};
  final ordered = <TerraCamera>[];
  final seen = <String>{};
  for (final s in sets) {
    final cam = s.camera == null ? null : byId[s.camera!.id];
    if (cam == null || !seen.add(cam.id)) continue;
    ordered.add(cam);
  }
  for (final c in cameras) {
    if (seen.add(c.id)) ordered.add(c);
  }
  return ordered;
}

class _CameraLiveAreaState extends ConsumerState<CameraLiveArea> {
  late final PageController _controller;

  /// 지금 시점의 정렬된 카메라 목록(read — 콜백용).
  List<TerraCamera> _orderedNow() => orderCamerasBySets(
        ref.read(camerasProvider).valueOrNull ?? const [],
        ref.read(enclosureSetsProvider).valueOrNull ?? const [],
      );

  /// 저장된 id → 인덱스 해석. 미선택(null)·목록에 없는 id는 **홈이 보고 있는
  /// 세트의 카메라**로 — 홈과 같은 화면이어야 "탭을 옮겼더니 딴 카메라"가
  /// 안 된다(2026-09-04 사용자 제보). 그것도 없으면 0.
  int _resolveIndex(
      List<TerraCamera> cameras, String? storedId, String? setCamId) {
    if (cameras.isEmpty) return 0;
    var i = storedId == null
        ? -1
        : cameras.indexWhere((c) => c.id == storedId);
    if (i >= 0) return i;
    i = setCamId == null ? -1 : cameras.indexWhere((c) => c.id == setCamId);
    return i >= 0 ? i : 0;
  }

  /// 여기서 고른 카메라를 홈에도 반영 — 그 카메라가 물린 세트가 있으면
  /// 홈 세트 선택을 옮긴다(TopFixedArea의 기존 listen이 페이지를 움직인다).
  void _syncHomeSet(String cameraId) {
    final sets =
        ref.read(enclosureSetsProvider).valueOrNull ?? const <EnclosureSet>[];
    final i = sets.indexWhere((s) => s.camera?.id == cameraId);
    if (i < 0) return; // 세트 밖 카메라 — 홈은 그대로 둔다.
    if (ref.read(selectedSetIndexProvider) == i) return;
    ref.read(selectedSetIndexProvider.notifier).state = i;
  }

  @override
  void initState() {
    super.initState();
    // 저장된 id를 그대로 믿지 않는다 — 목록에서 사라졌을 수 있다
    // (TopFixedArea와 같은 가드).
    _controller = PageController(
      initialPage: _resolveIndex(
        _orderedNow(),
        ref.read(selectedCrecamCameraProvider),
        ref.read(currentSetProvider).valueOrNull?.camera?.id,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 홈에서 세트를 바꾸면 따라간다(양방향 동기화의 홈→카메라 방향).
    // 세트의 카메라가 **실제로 바뀐** 전환에만 반응한다 — 재조회 재방출에도
    // 반응하면, 세트 밖 카메라를 보던 사용자를 홈 카메라로 끌어온다.
    // .when 안에 넣으면 로딩 빌드에서 listen이 풀리므로 build 최상단에 둔다.
    ref.listen<AsyncValue<EnclosureSet?>>(currentSetProvider, (prev, next) {
      final nextId = next.valueOrNull?.camera?.id;
      if (nextId == null || nextId == prev?.valueOrNull?.camera?.id) return;
      if (ref.read(selectedCrecamCameraProvider) == nextId) return;
      final i = _orderedNow().indexWhere((c) => c.id == nextId);
      if (i < 0) return; // 세트엔 있는데 카메라 목록엔 없는 stale 참조.
      ref.read(selectedCrecamCameraProvider.notifier).state = nextId;
      if (_controller.hasClients && _controller.page?.round() != i) {
        _controller.animateToPage(
          i,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

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

  Widget _liveSurface(List<TerraCamera> rawCameras) {
    // 홈 세트 순서로 재정렬 — 세트가 아직/에러면 원래 순서 그대로(라이브
    // 영역이 세트 로드 실패에 같이 죽으면 안 된다).
    final cameras = orderCamerasBySets(
      rawCameras,
      ref.watch(enclosureSetsProvider).valueOrNull ?? const [],
    );
    final storedId = ref.watch(selectedCrecamCameraProvider);
    // 세트는 **watch** — read면 카메라 목록이 세트 체인보다 먼저 도착하는
    // 콜드스타트/딥링크에서 폴백이 postFrame으로 저장돼 센티넬이 영구
    // 소모된다(리뷰 2026-09-04: bc451af가 고친 증상의 재현 경로).
    final setAsync = ref.watch(currentSetProvider);
    // 미선택인데 세트가 아직 로딩이면 해석·저장을 **보류**한다 — 임시로 첫
    // 카메라를 그리되 센티넬은 남겨, 세트 도착(watch 리빌드) 시 제대로
    // 해석한다. 세트 로딩이 에러로 끝나면 폴백 0 확정(영구 보류 방지).
    final resolvable = storedId != null || !setAsync.isLoading;
    final selected =
        _resolveIndex(cameras, storedId, setAsync.valueOrNull?.camera?.id);
    final selectedId = cameras[selected].id;
    // 해석 결과·목록에 없는 id는 저장값도 화면값에 맞춘다 — 남겨두면 클립
    // 그리드가 다른 카메라를 본다(TopFixedArea 선례). 컨트롤러 페이지는
    // 세트 도착으로 **순서가 바뀐** 경우에도 맞춘다(id는 같아도 인덱스가
    // 이동한다).
    final needsStore = resolvable && storedId != selectedId;
    final needsJump =
        _controller.hasClients && _controller.page?.round() != selected;
    if (needsStore || needsJump) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (needsStore) {
          ref.read(selectedCrecamCameraProvider.notifier).state = selectedId;
        }
        // initState 시점에 목록이 로딩이었으면 initialPage가 0으로 굳어
        // 있다 — 해석된 페이지로 점프.
        if (_controller.hasClients &&
            _controller.page?.round() != selected) {
          _controller.jumpToPage(selected);
        }
      });
    }
    final current = cameras[selected];

    final surface = LiveSurface(
      aspectRatio: CameraLiveArea.aspectRatio,
      // 좌상단 연결 배지 — 스트림 phase 기준(홈과 동일 공용 위젯, A3 복원).
      status: LiveConnectionBadge(cameraId: current.id),
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
          final id = cameras[i].id;
          if (ref.read(selectedCrecamCameraProvider) != id) {
            ref.read(selectedCrecamCameraProvider.notifier).state = id;
          }
          // 홈도 따라간다(양방향 동기화의 카메라→홈 방향).
          _syncHomeSet(id);
        },
        // 정착 페이지만 라이브 — 드래그로 스쳐 가는 이웃 페이지가 세션
        // 생성→즉시 철거(offer/ICE/closeSession 왕복)를 반복하지 않게
        // (리뷰 2026-09-04 효율). 정착(onPageChanged) 시 active가 되며 연결.
        itemBuilder: (_, i) =>
            _CameraPane(camera: cameras[i], active: i == selected),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Stack(
        children: [
          surface,
          Positioned(
            // Figma 668:446 실측 — 우 20(1021−1001)·하 12. 좌 이름 배지의
            // 12와 다르다(2026-09-07 재대조).
            right: 20,
            bottom: 12,
            child: _ExpandButton(
              key: CameraLiveArea.expandButtonKey,
              cameraId: current.id,
            ),
          ),
          // 어느 카메라를 보는지 — 구 카메라 그리드가 주던 식별 정보의 복원
          // (리뷰 2026-09-04: 다중 카메라에서 점 인디케이터만으론 알 수 없다).
          Positioned(
            left: 12,
            bottom: 12,
            child: _CameraNameBadge(name: current.name),
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
  const _CameraPane({required this.camera, required this.active});

  final TerraCamera camera;

  /// 정착된(선택) 페이지만 true — 스와이프 중 이웃 페이지는 연결하지 않는다.
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!active) return const SizedBox.expand();
    return WebRtcLiveView(cameraUuid: camera.id, cover: true);
  }
}

/// 좌하단 카메라 이름 배지 — 확장 버튼과 같은 스크림 캡슐.
class _CameraNameBadge extends StatelessWidget {
  const _CameraNameBadge({required this.name});

  final String name;

  static const badgeKey = Key('crecam_live_camera_name');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: badgeKey,
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.liveScrim,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 12 * -0.02,
          color: AppTheme.liveOnDark,
        ),
      ),
    );
  }
}

/// 우하단 확장 — 32pt 원형(black 30%), 라이브 전체화면으로(홈 _ExpandButton 문법).
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.liveScrim,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/crecam/cameras/$cameraId/live'),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.zoom_out_map, size: 17.5, color: AppTheme.liveOnDark),
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
                  ? AppTheme.liveOnDark
                  : AppTheme.liveOnDarkFaint,
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
