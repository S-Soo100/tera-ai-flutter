import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/glass_palette.dart';
import 'figma_icon.dart';

/// 하단 탭바 아래로 스크롤되는 리스트의 padding.
///
/// `extendBody: true`라 Scaffold가 body의 `MediaQuery.padding.bottom`에 탭바
/// 높이(홈 인디케이터 포함)를 더해준다 — padding을 **명시한** 스크롤 뷰는 그
/// 자동 인셋이 꺼지므로, 마지막 항목(저장 버튼·카드)이 바에 가려지지 않게 이
/// 헬퍼로 직접 소비한다. 화면마다 수기로 더하면 한 곳만 빠뜨려도 조용히
/// 가려진다.
///
/// 여유는 [AppStyles.spacing16] — B안 바는 불투명 고정 바라 플로팅 독(24)만큼
/// 숨 쉴 거리가 필요 없다.
EdgeInsets glassDockListPadding(BuildContext context,
    {EdgeInsets base = EdgeInsets.zero}) {
  return base +
      EdgeInsets.only(
        bottom: AppStyles.spacing16 + MediaQuery.paddingOf(context).bottom,
      );
}

/// 독 항목 하나. Figma 아이콘 에셋명 + 라벨.
///
/// Figma Navigation은 활성/비활성이 같은 글리프에 색만 다르다 — 아이콘 쌍
/// (기본/선택)이 아니라 단일 에셋을 [FigmaIcon.tinted]로 칠한다(2026-09-04).
class GlassDockItem {
  const GlassDockItem({
    required this.iconAsset,
    required this.label,
  });

  /// `assets/icons/{iconAsset}.svg`의 파일명(확장자 제외).
  final String iconAsset;
  final String label;
}

/// 하단 탭바. 디자인 시스템 `Components / GlassDock` (이름은 역사적 — A안
/// 플로팅 캡슐 시절의 것).
///
/// **2026-09-02 Figma `vivanaut app` Navigation(668:2485) 스타일**: 흰 바닥
/// ([GlassPalette.tabBar]) + top stroke [GlassPalette.surfaceTint]. 그림자
/// 없음. 4항목이 폭을 균등 분할하고, 활성 탭은 **primary(#192553)**,
/// 나머지는 [GlassPalette.textTertiary]. 아이콘 24 + 간격 4 + 라벨 12 Medium
/// ([GlassPalette.dockLabel]).
///
/// [height]는 SafeArea 아래 인셋을 뺀 콘텐츠 높이다 — 홈 인디케이터는
/// 안쪽 `SafeArea(top: false)`가 더한다. `Scaffold.bottomNavigationBar`에
/// 그대로 앉히고 `extendBody: true`를 유지하면 body 인셋 계약
/// ([glassDockListPadding])이 그대로 성립한다.
///
/// 네비게이션 로직은 갖지 않는다. [currentIndex]/[onSelected]만 받아
/// `StatefulNavigationShell` 등 호출자가 배선한다.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  /// 바 콘텐츠 높이(홈 인디케이터 제외). Figma 80은 safe area 포함 — 콘텐츠는 64.
  static const double height = 64;

  final List<GlassDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass.tabBar,
        border: Border(top: BorderSide(color: glass.surfaceTint)),
      ),
      // 리플이 앉을 면 — 없으면 잉크가 불투명 바 뒤에 그려져 안 보인다.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _DockButton(
                      item: items[i],
                      selected: i == currentIndex,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      unselectedColor: glass.textTertiary,
                      onTap: () => onSelected(i),
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
    final glass = context.glass;
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
        // Expanded 셀 전체(≥ 48×56)가 히트 타깃 — 접근성 최소 크기 충족.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FigmaIcon.tinted(item.iconAsset, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: glass.dockLabel.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
