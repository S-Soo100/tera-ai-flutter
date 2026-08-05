import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/device_mode.dart';
import 'home_set_providers.dart';
import 'widgets/home_header_bar.dart';
import 'widgets/home_sub_tabs_bar.dart';
import 'widgets/top_fixed_area.dart';

/// PRD §2 홈 탭 와이어프레임 조립.
///
/// Header / TopFixedArea / SubTabsBar 는 고정이고 그 아래 컨테이너만 바뀐다.
/// **TopFixedArea가 서브탭 컨테이너 밖에 있는 것이 핵심**이다 — 안에 두면
/// 탭 전환 때 WebRtcLiveView가 dispose되어 재연결(수초)이 걸린다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeSubTabProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeaderBar(),
            const TopFixedArea(),
            const HomeSubTabsBar(),
            Expanded(
              // IndexedStack: 두 컨테이너를 살려둔 채 보이는 것만 바꾼다.
              child: IndexedStack(
                index: tab == HomeSubTab.control ? 0 : 1,
                children: const [
                  _ControlContainer(),
                  _TimelineContainer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사육장 제어 서브탭. 내용은 Task 11~14에서 채운다.
class _ControlContainer extends StatelessWidget {
  const _ControlContainer();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 타임라인 서브탭. 내용은 Task 15~16에서 채운다.
class _TimelineContainer extends StatelessWidget {
  const _TimelineContainer();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
