import 'package:flutter/material.dart';

import 'tokens/variant_b_tokens.dart';
import 'variant_b_community_screen.dart';
import 'variant_b_home_screen.dart';
import 'variant_b_pets_screen.dart';
import 'variant_b_stats_screen.dart';

/// B안 — Flighty 스타일 4탭 셸.
///
/// 홈/통계/마이크레/커뮤니티를 IndexedStack으로 전환한다(로컬 state,
/// 라우터 무변경). 하단 탭바는 다크 미니멀 전광판 톤 — 활성 탭만 앰버.
class VariantBShell extends StatefulWidget {
  const VariantBShell({super.key});

  @override
  State<VariantBShell> createState() => _VariantBShellState();
}

class _VariantBShellState extends State<VariantBShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'HOME'),
    (
      icon: Icons.insert_chart_outlined,
      activeIcon: Icons.insert_chart,
      label: 'STATS'
    ),
    (icon: Icons.pets_outlined, activeIcon: Icons.pets, label: 'MY CRE'),
    (icon: Icons.forum_outlined, activeIcon: Icons.forum, label: 'BOARD'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantBTokens.background,
      body: IndexedStack(
        index: _index,
        children: const [
          VariantBHomeScreen(),
          VariantBStatsScreen(),
          VariantBPetsScreen(),
          VariantBCommunityScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: VariantBTokens.tabBar,
          border: Border(top: BorderSide(color: VariantBTokens.divider)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
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
        active ? VariantBTokens.tabActive : VariantBTokens.tabInactive;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(label, style: VariantBTokens.tabLabel.copyWith(color: color)),
        ],
      ),
    );
  }
}
