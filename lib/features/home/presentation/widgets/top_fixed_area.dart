import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../my_cage/domain/terra_camera.dart';
import '../../../my_cage/presentation/webrtc_live_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../../domain/enclosure_set.dart';
import '../../domain/pet_dday.dart';
import '../home_set_providers.dart';
import 'live_clock_overlay.dart';
import 'pet_profile_card.dart';

/// PRD §3.2 Top Fixed Area.
///
/// 캠이 있으면 라이브 뷰어, 없으면 개체 프로필 카드. 좌/우 스와이프로 세트를
/// 전환하고 하단 인디케이터가 이를 반영한다(PRD §3.2 스와이프 UX).
///
/// **4:3 고정**(A안 2차, 2026-08-14 — 16:9에서 키움)이라 아래 서브탭 컨텐츠
/// 높이가 바뀌어도 상단이 흔들리지 않는다. 비율은 [aspectRatio] 한 곳이다.
class TopFixedArea extends ConsumerStatefulWidget {
  const TopFixedArea({super.key});

  static const pageViewKey = Key('top_fixed_pageview');
  static const liveKey = Key('top_fixed_live');
  static const profileKey = Key('top_fixed_profile');
  static const indicatorKey = Key('top_fixed_indicator');

  /// 라이브/프로필 면 비율. 화면 폭 393pt 기준 높이 ~295pt.
  static const double aspectRatio = 4 / 3;

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
      return ColoredBox(
        color: AppTheme.liveSurface,
        child: AspectRatio(
          aspectRatio: TopFixedArea.aspectRatio,
          child: Center(
            child: Text('home_no_set'.tr(),
                style: const TextStyle(color: Colors.white70)),
          ),
        ),
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

    // 오버레이는 **면이 소유한다**. 페이지는 내용(영상/프로필)만 그린다 —
    // 슬롯이 페이지마다 흩어지면 위치가 달라지고, 인디케이터가 안내 문구와
    // 겹치는 일이 생긴다(실기기에서 그랬다).
    return LiveSurface(
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

class _SetPane extends ConsumerWidget {
  const _SetPane({required this.set});

  final EnclosureSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 이 영역은 **라이브 전용**이다. 녹화 클립은 전체화면 가로 플레이어로 간다
    // (`/crecam/motion-clips/:id`) — 여기서 재생하면 상단 조각 안에 갇힌다.
    final cam = set.camera;
    if (cam == null) {
      return Container(
        key: TopFixedArea.profileKey,
        alignment: Alignment.centerLeft,
        child: PetProfileCard(
          pet: set.pet,
          lastFedAt: null,
          status: EnvStatus.unknown,
        ),
      );
    }
    return KeyedSubtree(
      key: TopFixedArea.liveKey,
      // 풀블리드 면을 영상이 꽉 채운다 — contain이면 스트림 비율(16:9)과
      // 면 비율(4:3) 차이만큼 위아래 검은 띠가 남아 넓힌 의미가 없다.
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
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}
