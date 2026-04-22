import 'package:flutter/material.dart';

/// 0~23시 칩을 가로 스크롤로 표시하는 시간대 선택 바.
///
/// - 선택된 hour: primary 배경 + white text
/// - count=0인 칩: opacity 0.4, 탭 불가
/// - selectedHour 변경 시 해당 칩이 뷰포트 중앙에 오도록 animateTo
class HourChipRow extends StatefulWidget {
  const HourChipRow({
    super.key,
    required this.selectedHour,
    required this.counts,
    required this.onChanged,
  });

  final int selectedHour;

  /// key: 0~23, value: 해당 시간대 클립 개수. 없는 키는 0으로 취급.
  final Map<int, int> counts;
  final ValueChanged<int> onChanged;

  @override
  State<HourChipRow> createState() => _HourChipRowState();
}

class _HourChipRowState extends State<HourChipRow> {
  static const double _chipWidth = 56.0;
  static const double _chipHeight = 56.0;
  static const double _separatorWidth = 6.0;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 초기 렌더 후 선택된 칩으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(HourChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedHour != widget.selectedHour) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final viewportWidth = _scrollController.position.viewportDimension;
    // 선택 칩의 중심 x 좌표
    final chipCenter = widget.selectedHour * (_chipWidth + _separatorWidth) +
        _chipWidth / 2;
    // 뷰포트 중앙에 오도록 offset 계산
    final targetOffset = chipCenter - viewportWidth / 2;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxExtent);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _chipHeight + 8, // 상하 패딩 포함
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: 24,
        separatorBuilder: (_, __) =>
            const SizedBox(width: _separatorWidth),
        itemBuilder: (context, hour) {
          final count = widget.counts[hour] ?? 0;
          final isSelected = hour == widget.selectedHour;
          final isDisabled = count == 0;

          final bgColor = isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHigh;
          final textColor = isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurface;
          final opacity = isDisabled && !isSelected ? 0.4 : 1.0;

          return Opacity(
            opacity: opacity,
            child: GestureDetector(
              onTap: isDisabled ? null : () => widget.onChanged(hour),
              child: Container(
                width: _chipWidth,
                height: _chipHeight,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$hour시',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0 ? '—' : '$count',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.85)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
