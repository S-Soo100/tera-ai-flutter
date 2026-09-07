import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';

/// 요약 수치 한 줄. 디자인 시스템 `Patterns / StatRow`.
///
/// **누르는 칩이 아니라 읽는 값이다.** 칩 모양으로 만들면 바로 아래 필터 칩과
/// 구분이 안 된다 — 박스를 두르지 않는 이유다.
///
/// [caption]에 집계 기준을 밝힌다. 밝히지 않으면 다른 구간의 목록과 나란히
/// 놓였을 때 숫자가 안 맞는 것처럼 보인다.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items, this.caption});

  final List<StatItem> items;

  /// 집계 기준 표시. 예: `밤 10시–6시 기준`.
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) ...[
            caption!,
            const SizedBox(height: AppStyles.spacing8),
          ],
          // **균등 분할하지 않는다.** 값 길이 편차가 크면(`0분` vs `16시간 38분`)
          // 짧은 칸은 여백만 남고 긴 칸이 옆 칸을 침범한다. 자연 폭으로 두고
          // 다 안 들어가면 가로로 넘긴다.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppStyles.spacing24),
                  _Stat(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatItem {
  const StatItem(
      {required this.label, required this.value, this.isZero = false});

  final String label;
  final String value;

  /// 0건인가. **없다는 사실은 정보지만 주인공은 아니다** — 흐리게 둔다.
  final bool isZero;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.item});

  final StatItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.value,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: item.isZero ? FontWeight.w600 : FontWeight.w700,
            letterSpacing: -0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: item.isZero
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          item.label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          maxLines: 1,
        ),
      ],
    );
  }
}
