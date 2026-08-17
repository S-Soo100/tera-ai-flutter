import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'lab_mode_toggle.dart';
import 'tokens/variant_b_tokens.dart';
import 'variant_b_community_screen.dart';
import 'variant_b_home_screen.dart';
import 'variant_b_pets_screen.dart';
import 'variant_b_stats_screen.dart';

/// B안 — Flighty 스타일 4탭 셸.
///
/// 홈/통계/마이크레/커뮤니티를 IndexedStack으로 전환한다(로컬 state,
/// 라우터 무변경). 하단 탭바는 미니멀 전광판 톤 — 활성 탭만 앰버.
///
/// 다크/라이트(2026-08-14 오후): 토큰 한 벌을 [BLabTheme]으로 내려보낸다.
/// 기본은 시스템 밝기, 우상단 ☀️/🌙(EXIT 옆)로 즉시 전환(랩 로컬 state).
class VariantBShell extends StatefulWidget {
  const VariantBShell({super.key});

  @override
  State<VariantBShell> createState() => _VariantBShellState();
}

class _VariantBShellState extends State<VariantBShell> {
  int _index = 0;

  /// null = 시스템 밝기 따름. 토글하면 고정.
  Brightness? _override;

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
    final brightness = _override ?? MediaQuery.platformBrightnessOf(context);
    final t = brightness == Brightness.dark
        ? const VariantBTokens.dark()
        : const VariantBTokens.light();
    return BLabTheme(
      tokens: t,
      child: LabThemeScope(
        brightness: brightness,
        child: Scaffold(
          backgroundColor: t.background,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LabModeToggle(
                          brightness: brightness,
                          onToggle: () => setState(() {
                            _override = brightness == Brightness.dark
                                ? Brightness.light
                                : Brightness.dark;
                          }),
                          builder: (context, icon) => _BoardButton(icon: icon),
                        ),
                        const SizedBox(width: 8),
                        _ExitButton(onTap: () => context.pop()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: t.tabBar,
              border: Border(top: BorderSide(color: t.divider)),
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
                          icon:
                              _index == i ? _tabs[i].activeIcon : _tabs[i].icon,
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
        ),
      ),
    );
  }
}

/// 전광판 톤 작은 버튼 상자 — EXIT·모드 토글이 같은 문법을 쓴다.
/// 라이브 헤더(영상) 위에서도 읽히게 배경 톤 스크림을 깐다.
class _BoardButton extends StatelessWidget {
  const _BoardButton({this.icon, this.label});

  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = VariantBTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: t.textSecondary),
          if (icon != null && label != null) const SizedBox(width: 5),
          if (label != null) Text(label!, style: t.dataLabel),
        ],
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
        child: const _BoardButton(icon: Icons.arrow_back, label: 'EXIT'),
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
    final color = active
        ? VariantBTokens.of(context).tabActive
        : VariantBTokens.of(context).tabInactive;
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
