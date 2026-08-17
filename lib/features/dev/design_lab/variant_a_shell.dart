import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import 'tokens/variant_a_tokens.dart';
import 'variant_a_community_screen.dart';
import 'variant_a_home_screen.dart';
import 'variant_a_pets_screen.dart';
import 'variant_a_stats_screen.dart';
import 'variant_a_widgets.dart';

/// A안 — 솔리드 다크(2차) 4탭 셸.
///
/// B 셸과 같은 방식(IndexedStack + 로컬 state, 라우터 무변경)이되
/// 탭바는 실앱 독 문법: 플로팅 솔리드 캡슐 + 아이콘/라벨, 콘텐츠가
/// 그 뒤로 스크롤된다. 스크롤 내리면 독이 축소된다(iOS 26).
/// `AppTheme`·실 `GlassDock` 미참조 — 랩 격리 유지.
class VariantAShell extends StatefulWidget {
  const VariantAShell({super.key});

  @override
  State<VariantAShell> createState() => _VariantAShellState();
}

class _VariantAShellState extends State<VariantAShell> {
  int _index = 0;

  /// 스크롤 방향에 따라 독 축소/복원 — 어느 탭에서 올라온 알림이든 받는다.
  bool _dockShrunk = false;

  static const _tabs = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '홈'),
    (icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: '통계'),
    (icon: Icons.pets_outlined, selectedIcon: Icons.pets, label: '마이크레'),
    (
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: '커뮤니티'
    ),
  ];

  bool _onScroll(UserScrollNotification n) {
    final shrink = n.direction == ScrollDirection.reverse;
    if (shrink != _dockShrunk && n.direction != ScrollDirection.idle) {
      setState(() => _dockShrunk = shrink);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantATokens.wallpaperTop,
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: IndexedStack(
              index: _index,
              children: [
                // IndexedStack은 다른 탭도 살려 두므로 visible을 내려보내지
                // 않으면 mock 라이브가 안 보이는 탭 뒤에서 계속 돈다.
                VariantAHomeScreen(visible: _index == 0),
                const VariantAStatsScreen(),
                const VariantAPetsScreen(),
                const VariantACommunityScreen(),
              ],
            ),
          ),
          // 랩 나가기 — 시안 셸은 pushed 최상위 라우트라, 자기 문법(유리
          // 캡슐)의 뒤로 어포던스가 없으면 시스템 제스처 말곤 출구가 없다.
          // 홈 헤더의 접힌 제목이 52pt에서 시작해 좌상단이 비어 있다.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: _BackCapsule(onTap: () => context.pop()),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _GlassTabDock(
              tabs: _tabs,
              index: _index,
              shrunk: _dockShrunk,
              onSelected: (i) => setState(() {
                _index = i;
                _dockShrunk = false; // 탭 전환 시 독 복원.
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// 좌상단 유리 캡슐 뒤로 버튼(＜) — A안 문법의 나가기.
class _BackCapsule extends StatelessWidget {
  const _BackCapsule({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '뒤로',
      child: GestureDetector(
        onTap: onTap,
        child: const AGlass(
          radius: 100,
          overlay: VariantATokens.glassOverlayStrong,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: VariantATokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 실앱 `GlassDock` 문법을 랩 토큰으로 재현한 유리 독 —
/// 캡슐 + 아이콘/라벨 버튼 + 스크롤 축소 모션.
class _GlassTabDock extends StatelessWidget {
  const _GlassTabDock({
    required this.tabs,
    required this.index,
    required this.shrunk,
    required this.onSelected,
  });

  final List<({IconData icon, IconData selectedIcon, String label})> tabs;
  final int index;
  final bool shrunk;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + 12),
      child: AnimatedScale(
        scale: shrunk ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        // 축소 시 흐림은 Opacity 레이어가 아니라 **decoration 알파**로 낸다 —
        // AnimatedOpacity는 saveLayer를 하나 더 쌓는다(quick_control_grid의
        // 단일 표면 전례).
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: shrunk ? 0.55 : 1.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => AGlass(
            radius: 100,
            overlay: VariantATokens.glassOverlayStrong
                .withValues(alpha: VariantATokens.glassOverlayStrong.a * t),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: child!,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _DockButton(
                  icon: i == index ? tabs[i].selectedIcon : tabs[i].icon,
                  label: tabs[i].label,
                  selected: i == index,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? VariantATokens.textPrimary
        : VariantATokens.textSecondary;

    // excludeSemantics가 자식 InkWell의 tap 액션까지 지우므로 onTap을 직접 단다
    // (실앱 GlassDock과 동일).
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        // 접근성 히트 타깃 48dp 보장(실앱 독과 동일).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
