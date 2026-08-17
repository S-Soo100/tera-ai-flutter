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

/// 플로팅 독. 디자인 시스템 `Components / GlassDock` (A안 — 이름은 역사적).
///
/// 화면 하단에 **떠 있는 캡슐**이고 콘텐츠는 그 뒤로 스크롤된다
/// (`Scaffold.extendBody: true` 전제). A안 2차(2026-08-14, 솔리드)부터는
/// blur 없이 **바닥보다 확실히 밝은 불투명 표면 + 미세 그림자**로 떠 있는
/// 느낌만 낸다.
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
  });

  final List<GlassDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // 전역 다크 고정 — 바닥이 항상 어두우니 전경은 흰 계열 하나다.
    const selectedColor = AppTheme.glassTextPrimary;
    const unselectedColor = AppTheme.glassTextSecondary;

    return DecoratedBox(
      // 그림자는 카드 밖에 둔다 — GlassCard가 ClipRRect로 자르므로 안에
      // 넣으면 잘려 나간다. 콘텐츠가 뒤로 지나가는 유일한 표면이라
      // 그림자 하나로 "떠 있음"을 말한다.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GlassCard(
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
    // excludeSemantics는 자식 InkWell의 **tap 액션까지** 지우므로, 스크린리더가
    // 활성화할 수 있게 onTap을 이 노드에 직접 단다.
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: item.label,
      onTap: onTap,
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
