import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// 세그먼트 항목 하나.
class GlassSegment<T> {
  const GlassSegment({
    required this.value,
    required this.label,
    this.enabled = true,
    this.itemKey,
  });

  final T value;
  final String label;
  final bool enabled;

  /// 테스트에서 항목을 집을 키. 탭 대상(항목 전체)에 붙는다.
  final Key? itemKey;
}

/// 유리 세그먼트. 디자인 시스템 `Components / GlassSegmentedControl` (A안).
///
/// 홈 서브탭(`HomeSubTabsBar`)이 세운 문법의 공용판 — 유리 트랙(캡슐) 안에서
/// **선택 항목만 불투명 흰 알약**([AppTheme.glassActiveTile])으로 뜬다.
/// 밑줄·체크 대신 면으로 말한다(Apple Home 문법).
///
/// 선택 로직은 갖지 않는다. [selected]/[onChanged]만 받아 호출자가 배선한다.
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 100,
      padding: const EdgeInsets.all(AppStyles.spacing4),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: _SegmentTab(
                key: s.itemKey,
                label: s.label,
                enabled: s.enabled,
                selected: s.value == selected,
                onTap: () => onChanged(s.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    super.key,
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOn = selected && enabled;
    final Color fg;
    if (!enabled) {
      fg = AppTheme.glassTextTertiary;
    } else if (isOn) {
      fg = AppTheme.glassTextOnActive;
    } else {
      fg = AppTheme.glassTextSecondary;
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing8),
        decoration: BoxDecoration(
          color: isOn ? AppTheme.glassActiveTile : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.glassTileTitle.copyWith(
            fontSize: 14,
            color: fg,
            fontWeight: isOn ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
