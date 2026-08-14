import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              // IndexedStack은 다른 탭도 살려 두므로 visible을 내려보내지
              // 않으면 mock 라이브가 안 보이는 탭 뒤에서 계속 돈다.
              VariantBHomeScreen(visible: _index == 0),
              const VariantBStatsScreen(),
              const VariantBPetsScreen(),
              const VariantBCommunityScreen(),
            ],
          ),
          // 랩 나가기 — pushed 라우트라 자기 문법의 출구가 필요하다. 홈의
          // LIVE 라벨이 좌상단을 쓰므로 우상단에 전광판 톤 ← EXIT.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: _ExitButton(onTap: () => context.pop()),
              ),
            ),
          ),
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

/// 전광판 톤 나가기(← EXIT) — B안 문법의 뒤로 어포던스.
class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '뒤로',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            // 라이브 헤더(영상) 위에서도 읽히게 배경 톤 스크림을 깐다.
            color: const Color(0xCC0B0F1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VariantBTokens.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.arrow_back,
                  size: 14, color: VariantBTokens.textSecondary),
              SizedBox(width: 5),
              Text('EXIT', style: VariantBTokens.dataLabel),
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
