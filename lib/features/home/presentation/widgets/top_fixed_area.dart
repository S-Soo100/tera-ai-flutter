import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../my_cage/domain/terra_camera.dart';
import '../../../my_cage/presentation/webrtc_live_controller.dart';
import '../../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../../domain/enclosure_set.dart';
import '../home_set_providers.dart';
import 'live_clock_overlay.dart';

/// 홈 라이브 영역 — Figma A.4 ② (369×271, radius 12는 홈이 ClipRRect로 감쌈).
///
/// PRD 재설계(2026-09-02)로 **라이브 전용**이 됐다 — 개체 프로필 카드 분기는
/// 폐기(단일 스크롤 홈, §4.1). 좌/우 스와이프 세트 전환·LIVE/OFFLINE 뱃지·
/// 재연결은 유지.
///
/// 캠 배치에 따라 세 갈래다:
/// - 세트 없음 → 한 줄 안내(`home_no_set`)로 접힌다
/// - **어느 세트에도 캠이 없음 → 라이브 자리 생략**, 한 줄 안내(`home_no_camera`)
/// - 캠이 하나라도 있음 → 라이브 면. 캠 없는 세트의 페이지는 면 안에 안내 한 줄
///   (PageView 높이는 페이지마다 다를 수 없어, 면 자체는 유지한다)
class TopFixedArea extends ConsumerStatefulWidget {
  const TopFixedArea({super.key});

  static const pageViewKey = Key('top_fixed_pageview');
  static const liveKey = Key('top_fixed_live');
  static const noCameraPaneKey = Key('top_fixed_no_camera_pane');
  static const noCameraLineKey = Key('top_fixed_no_camera_line');
  static const indicatorKey = Key('top_fixed_indicator');

  /// 라이브 면 비율 — Figma 실측 369×271.
  static const double aspectRatio = 369 / 271;

  @override
  ConsumerState<TopFixedArea> createState() => _TopFixedAreaState();
}

class _TopFixedAreaState extends ConsumerState<TopFixedArea> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    // 저장된 인덱스를 그대로 믿지 않는다. selectedSetIndexProvider는
    // autoDispose가 아니고 계정 전환 시 초기화되지도 않아, 세트가 더 많던
    // 계정에서 넘어오면 itemCount를 넘는 값이 남아 있을 수 있다. 그대로 쓰면
    // PageView가 없는 페이지에서 시작해 상단 영역이 빈 화면이 된다.
    final known = ref.read(enclosureSetsProvider).valueOrNull?.length ?? 0;
    final saved = ref.read(selectedSetIndexProvider);
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
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];

    // 드롭다운 등 외부에서 인덱스가 바뀌면 페이지를 따라 움직인다.
    // 같은 값이면 아무것도 하지 않는다 — onPageChanged와 서로를 다시 부르는
    // 무한 루프를 막기 위한 가드.
    ref.listen<int>(selectedSetIndexProvider, (_, next) {
      if (!_controller.hasClients || sets.isEmpty) return;
      final target = next.clamp(0, sets.length - 1);
      if (_controller.page?.round() == target) return;
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });

    if (sets.isEmpty) {
      return const _InlineNotice(textKey: 'home_no_set');
    }

    // 캠이 하나도 없으면 271pt 어두운 면을 세워둘 이유가 없다 — 자리를
    // 접고 한 줄로 말한다(계획서 Task 4 유의 4). 세트 전환은 헤더 필이 맡는다.
    final hasAnyCamera = sets.any((s) => s.camera != null);
    if (!hasAnyCamera) {
      return const _InlineNotice(
        key: TopFixedArea.noCameraLineKey,
        textKey: 'home_no_camera',
      );
    }

    // 세트 목록이 줄어든 뒤(계정 전환·사육장 삭제) 저장된 인덱스가 범위를
    // 넘은 채 남으면, 나중에 세트가 다시 늘었을 때 엉뚱한 세트로 튄다.
    // 화면에 보이는 값(clamp된 것)과 저장된 값을 여기서 일치시킨다.
    final stored = ref.watch(selectedSetIndexProvider);
    if (stored > sets.length - 1 || stored < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(selectedSetIndexProvider.notifier).state =
            stored.clamp(0, sets.length - 1);
      });
    }

    final current =
        sets[ref.watch(selectedSetIndexProvider).clamp(0, sets.length - 1)];

    // 오버레이는 **면이 소유한다**. 페이지는 내용(영상/안내)만 그린다 —
    // 슬롯이 페이지마다 흩어지면 위치가 달라지고, 인디케이터가 안내 문구와
    // 겹치는 일이 생긴다(실기기에서 그랬다).
    //
    // TEMP/HUMIDITY 전광판 오버레이(live_stat_overlay)는 뺐다 — 같은 수치가
    // 바로 아래 온습도 요약 카드에 있다(2026-09-02). 시계 오버레이는 유지.
    final surface = LiveSurface(
      aspectRatio: TopFixedArea.aspectRatio,
      status: _ConnectionStatus(camera: current.camera),
      corner: current.camera == null ? null : const LiveClockOverlay(),
      footer: sets.length > 1
          ? _PageDots(
              key: TopFixedArea.indicatorKey,
              count: sets.length,
              current:
                  ref.watch(selectedSetIndexProvider).clamp(0, sets.length - 1),
            )
          : null,
      child: PageView.builder(
        key: TopFixedArea.pageViewKey,
        controller: _controller,
        itemCount: sets.length,
        onPageChanged: (i) {
          if (ref.read(selectedSetIndexProvider) == i) return;
          ref.read(selectedSetIndexProvider.notifier).state = i;
        },
        itemBuilder: (_, i) => _SetPane(set: sets[i]),
      ),
    );

    final cam = current.camera;
    if (cam == null) return surface;
    // Figma 668:859 — 우하단 전체보기. 라이브 전용 전체화면이 없어
    // 카메라 상세(라이브 크게 보기)로 보낸다.
    return Stack(
      children: [
        surface,
        Positioned(
          right: 12,
          bottom: 12,
          child: _ExpandButton(cameraId: cam.id),
        ),
      ],
    );
  }
}

/// 라이브 우하단 전체보기(Figma 668:859 — 32×32 radius 16, black 30%).
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.liveScrim,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/crecam/cameras/$cameraId'),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.zoom_out_map, size: 17, color: AppTheme.liveOnDark),
        ),
      ),
    );
  }
}

/// 접힌 자리의 한 줄 안내 — 큰 면 대신 조용히 말한다.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({super.key, required this.textKey});

  final String textKey;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        textKey.tr(),
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 14 * -0.02,
          color: glass.textTertiary,
        ),
      ),
    );
  }
}

/// 연결 상태 배지 — **한 번에 하나의 진실만 말한다.**
///
/// 이전에는 배지가 DB presence(`cameras.is_online`)를, 가운데 문구가 스트림
/// 상태를 말해서 `OFFLINE`과 "카메라 호출 중..."이 동시에 떴다. 이제 배지는
/// **스트림 phase**를 따르고, 연결 중일 때는 아예 배지를 내지 않는다 —
/// 가운데 문구가 이미 그 말을 하고 있기 때문이다.
class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus({required this.camera});

  final TerraCamera? camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = camera;
    if (cam == null) return const SizedBox.shrink();

    final phase = ref.watch(webrtcLiveControllerProvider(cam.id)).phase;
    return switch (phase) {
      WebRtcLivePhase.streaming => const StatusBadge(
          label: 'LIVE',
          tone: StatusTone.live,
          onDark: true,
        ),
      WebRtcLivePhase.failed => StatusBadge(
          label: 'home_live_offline'.tr(),
          tone: StatusTone.neutral,
          onDark: true,
        ),
      // 연결 중 — 가운데 문구가 이미 말한다. 배지까지 내면 중복이다.
      _ => const SizedBox.shrink(),
    };
  }
}

class _SetPane extends StatelessWidget {
  const _SetPane({required this.set});

  final EnclosureSet set;

  @override
  Widget build(BuildContext context) {
    // 이 영역은 **라이브 전용**이다. 녹화 클립은 전체화면 가로 플레이어로 간다
    // (`/crecam/motion-clips/:id`) — 여기서 재생하면 상단 조각 안에 갇힌다.
    final cam = set.camera;
    if (cam == null) {
      // 다른 세트에 캠이 있어 면은 서 있는 경우 — 이 세트만 안내 한 줄.
      return LiveSurfaceNotice(
        key: TopFixedArea.noCameraPaneKey,
        title: 'home_no_camera'.tr(),
      );
    }
    return KeyedSubtree(
      key: TopFixedArea.liveKey,
      // 풀블리드 면을 영상이 꽉 채운다 — contain이면 스트림 비율(16:9)과
      // 면 비율 차이만큼 위아래 검은 띠가 남는다.
      child: WebRtcLiveView(cameraUuid: cam.id, cover: true),
    );
  }
}

/// 어두운 라이브 면 위에 놓이므로 색을 테마가 아니라 직접 정한다.
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
              // 어두운 라이브 면 위라 테마 색을 쓰면 안 보인다.
              color: i == current
                  ? AppTheme.liveOnDark
                  : AppTheme.liveOnDarkFaint,
            ),
          ),
      ],
    );
  }
}
