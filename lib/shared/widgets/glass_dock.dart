import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// 독 항목 하나. 아이콘 쌍(기본/선택) + 라벨.
class GlassDockItem {
  const GlassDockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 플로팅 유리 독. 디자인 시스템 `Components / GlassDock` (A안 Liquid Glass).
///
/// iOS 26 탭바 문법 — 화면 하단에 **떠 있는 캡슐**이고, 콘텐츠는 그 뒤로
/// 스크롤되어 blur에 비친다(`Scaffold.extendBody: true` 전제).
///
/// 네비게이션 로직은 갖지 않는다. [currentIndex]/[onSelected]만 받아
/// `StatefulNavigationShell` 등 호출자가 배선한다.
///
/// 스크롤 축소/복원 모션은 이 단계에서 넣지 않았다(고정 독) — 후속 작업.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.onDark = true,
  });

  final List<GlassDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// 뒤에 깔린 콘텐츠가 어두운가. 어두우면 흰 전경, 밝으면 잉크 전경 —
  /// 유리는 반투명이라 전경색이 **바닥**을 따라가야 읽힌다.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        onDark ? AppTheme.glassTextPrimary : AppTheme.glassTextOnActive;
    final unselectedColor =
        onDark ? AppTheme.glassTextSecondary : AppTheme.glassTextOnActiveSecondary;

    return GlassCard(
      radius: 100,
      overlay: AppTheme.glassOverlayStrong,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _DockButton(
              item: items[i],
              selected: i == currentIndex,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final GlassDockItem item;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? item.selectedIcon : item.icon,
                size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
