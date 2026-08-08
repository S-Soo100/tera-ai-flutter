import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../../domain/enclosure_set.dart';
import '../../domain/pet_dday.dart';
import '../home_set_providers.dart';
import 'live_clock_overlay.dart';
import 'pet_profile_card.dart';
import 'timeline_clip_feed.dart';

/// PRD §3.2 Top Fixed Area.
///
/// 캠이 있으면 라이브 뷰어, 없으면 개체 프로필 카드. 좌/우 스와이프로 세트를
/// 전환하고 하단 인디케이터가 이를 반영한다(PRD §3.2 스와이프 UX).
///
/// 16:9 고정이라 아래 서브탭 컨텐츠 높이가 바뀌어도 상단이 흔들리지 않는다.
class TopFixedArea extends ConsumerStatefulWidget {
  const TopFixedArea({super.key});

  static const pageViewKey = Key('top_fixed_pageview');
  static const liveKey = Key('top_fixed_live');
  static const profileKey = Key('top_fixed_profile');
  static const indicatorKey = Key('top_fixed_indicator');

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
          aspectRatio: 16 / 9,
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

    // 라이브 영역은 **어두운 면 위**에 올린다. 밝은 배경에 두면 연결 전·오프라인
    // 상태가 죽은 공백으로 보인다. 인디케이터도 이 면 안에 넣어 하나의 덩어리로
    // 읽히게 한다 — 밖으로 빼면 라이브와 제어 바 사이에 떠 있는 조각이 된다.
    return ColoredBox(
      color: AppTheme.liveSurface,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
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
          ),
          if (sets.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppStyles.spacing8,
              child: Center(
                key: TopFixedArea.indicatorKey,
                child: _PageDots(
                  count: sets.length,
                  current: ref
                      .watch(selectedSetIndexProvider)
                      .clamp(0, sets.length - 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetPane extends ConsumerWidget {
  const _SetPane({required this.set});

  final EnclosureSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PRD §3.5: 클립 썸네일 터치 시 이 영역에서 바로 재생한다(화면 이동 아님).
    final playing = ref.watch(inlinePlayingClipProvider);
    if (playing != null) {
      return _InlineClipPlayer(
        clipId: playing.id,
        onClose: () =>
            ref.read(inlinePlayingClipProvider.notifier).state = null,
      );
    }

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
    return Stack(
      key: TopFixedArea.liveKey,
      fit: StackFit.expand,
      children: [
        WebRtcLiveView(cameraUuid: cam.id),
        Positioned(
          left: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: _LiveBadge(isOnline: cam.isOnline),
        ),
        const Positioned(
          right: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: LiveClockOverlay(),
        ),
        // 오프라인 안내 레이어를 여기서 그리지 않는다.
        // WebRtcLiveView가 연결 단계(config/offering/ice)와 실패(아이콘+문구+
        // 재시도)를 이미 자체적으로 그린다. 위에 레이어를 덧대면 "연결이
        // 끊겼습니다"와 "카메라 호출 중..."이 동시에 떠 서로 모순된다.
        // 상단 배지(LIVE/OFFLINE)는 DB presence, 가운데는 실제 스트림 상태 —
        // 두 정보의 출처를 분리해 둔다.
      ],
    );
  }
}

/// 상단 영역 인라인 클립 플레이어.
///
/// `initialize()`가 실패하면 catch에서 반드시 dispose 한다 — 안 하면 네이티브
/// 플레이어 리소스가 샌다.
class _InlineClipPlayer extends ConsumerStatefulWidget {
  const _InlineClipPlayer({required this.clipId, required this.onClose});

  final String clipId;
  final VoidCallback onClose;

  @override
  ConsumerState<_InlineClipPlayer> createState() => _InlineClipPlayerState();
}

class _InlineClipPlayerState extends ConsumerState<_InlineClipPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VideoPlayerController? c;
    try {
      final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
      c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
      await c.play();
    } catch (_) {
      // 실패해도 네이티브 리소스는 반드시 반납한다.
      await c?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_failed)
          Center(child: Text('home_clip_play_failed'.tr()))
        else if (c == null)
          const ColoredBox(color: Colors.black)
        else
          VideoPlayer(c),
        Positioned(
          right: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'home_back_to_live'.tr(),
            onPressed: widget.onClose,
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? Colors.red : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOnline ? 'LIVE' : 'OFFLINE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 어두운 라이브 면 위에 놓이므로 색을 테마가 아니라 직접 정한다.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

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
