import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/glass_palette.dart';

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

/// 세그먼트. 디자인 시스템 `Components / GlassSegmentedControl` (이름은
/// 역사적 — A안 반전 알약 시절의 것).
///
/// **B안(2026-08-14 저녁) 문법**: 트랙·채움 알약 없이 **앰버 텍스트 + 얇은
/// 앰버 밑줄**(FIDS 위계 — 면이 아니라 색·선으로 말한다). 비선택은 2차
/// 텍스트색, 비활성은 3차. 항목 아래로 divider 한 줄이 깔려 밑줄이 그 위에
/// 앉는다.
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

  /// 밑줄 굵기.
  static const double underline = 2;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: glass.border, width: 0.5)),
      ),
      // 리플이 앉을 면 — 카드 없이 바닥 위에 바로 놓이는 위젯이라 직접 깐다.
      child: Material(
        type: MaterialType.transparency,
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
    final glass = context.glass;
    final isOn = selected && enabled;
    final Color fg;
    if (!enabled) {
      fg = glass.textTertiary;
    } else if (isOn) {
      fg = glass.signalWarn;
    } else {
      fg = glass.textSecondary;
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppStyles.spacing8,
              horizontal: AppStyles.spacing4,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: glass.tileTitle.copyWith(
                fontSize: 14,
                color: fg,
                fontWeight: isOn ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          // 밑줄은 항상 자리를 차지한다(높이 튐 방지) — 색만 켜고 끈다.
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: GlassSegmentedControl.underline,
            color: isOn ? glass.signalWarn : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
