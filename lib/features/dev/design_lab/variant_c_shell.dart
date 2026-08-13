import 'package:flutter/material.dart';

import 'tokens/variant_c_tokens.dart';
import 'variant_c_community_screen.dart';
import 'variant_c_home_screen.dart';
import 'variant_c_pets_screen.dart';
import 'variant_c_stats_screen.dart';

/// C안 — Copilot Money 스타일 4탭 셸.
///
/// 홈/통계/마이크레/커뮤니티를 IndexedStack으로 전환한다(로컬 state,
/// 라우터 무변경). 하단 탭바는 라이트 라운드 파스텔 — 떠 있는 필 형태,
/// 활성 탭은 파스텔 캡슐 배경 + 컬러 아이콘.
class VariantCShell extends StatefulWidget {
  const VariantCShell({super.key});

  @override
  State<VariantCShell> createState() => _VariantCShellState();
}

class _VariantCShellState extends State<VariantCShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '홈'),
    (
      icon: Icons.donut_small_outlined,
      activeIcon: Icons.donut_small,
      label: '통계'
    ),
    (icon: Icons.pets_outlined, activeIcon: Icons.pets, label: '마이크레'),
    (
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: '커뮤니티'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantCTokens.background,
      // extendBody는 안 쓴다 — 기존 홈 화면의 하단 패딩(32)이 떠 있는 필에
      // 가려지는 걸 막으려면 body가 탭바 위에서 끝나야 한다.
      body: IndexedStack(
        index: _index,
        children: const [
          VariantCHomeScreen(),
          VariantCStatsScreen(),
          VariantCPetsScreen(),
          VariantCCommunityScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: VariantCTokens.tabBar,
            borderRadius:
                BorderRadius.circular(VariantCTokens.tabBarRadius),
            boxShadow: const [VariantCTokens.cardShadow],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: _index == i ? _tabs[i].activeIcon : _tabs[i].icon,
                    label: _tabs[i].label,
                    active: _index == i,
                    onTap: () => setState(() => _index = i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? VariantCTokens.tabActive : VariantCTokens.tabInactive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? VariantCTokens.tabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              // 활성 탭만 라벨을 펼친다 — 파스텔 캡슐 문법.
              if (active) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: VariantCTokens.tabLabel.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
