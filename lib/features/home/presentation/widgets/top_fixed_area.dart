import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../../domain/enclosure_set.dart';
import '../../domain/pet_dday.dart';
import '../home_set_providers.dart';
import 'pet_profile_card.dart';

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
    _controller =
        PageController(initialPage: ref.read(selectedSetIndexProvider));
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
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: Text('home_no_set'.tr())),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
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
          Padding(
            key: TopFixedArea.indicatorKey,
            padding: const EdgeInsets.only(top: AppStyles.spacing8),
            child: _PageDots(
              count: sets.length,
              current:
                  ref.watch(selectedSetIndexProvider).clamp(0, sets.length - 1),
            ),
          ),
      ],
    );
  }
}

class _SetPane extends StatelessWidget {
  const _SetPane({required this.set});

  final EnclosureSet set;

  @override
  Widget build(BuildContext context) {
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
        Positioned(
          right: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: Text(
            DateFormat('yyyy.MM.dd HH:mm').format(DateTime.now()),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        if (!cam.isOnline)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Text(
              'home_cam_disconnected'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
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
              color: i == current
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).disabledColor,
            ),
          ),
      ],
    );
  }
}
