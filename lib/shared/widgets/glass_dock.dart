import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// 플로팅 독 아래로 스크롤되는 리스트의 padding.
///
/// `extendBody: true`라 Scaffold가 body의 `MediaQuery.padding.bottom`에 독
/// 높이를 더해준다 — padding을 **명시한** 스크롤 뷰는 그 자동 인셋이 꺼지므로,
/// 마지막 항목(저장 버튼·카드)이 독에 가려지지 않게 이 헬퍼로 직접 소비한다.
/// 화면마다 수기로 더하면 한 곳만 빠뜨려도 조용히 가려진다.
EdgeInsets glassDockListPadding(BuildContext context,
    {EdgeInsets base = EdgeInsets.zero}) {
  return base +
      EdgeInsets.only(
        bottom: AppStyles.spacing24 + MediaQuery.paddingOf(context).bottom,
      );
}

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
    final unselectedColor = onDark
        ? AppTheme.glassTextSecondary
        : AppTheme.glassTextOnActiveSecondary;

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
    // 라벨은 Semantics가 말한다 — 안의 아이콘·텍스트까지 읽히면 겹말이 된다.
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        // 접근성 히트 타깃 48dp 보장 — 콘텐츠만으로는 ~46dp라 살짝 모자란다.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );
  }
}
