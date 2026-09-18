import 'package:flutter/material.dart';
import '../../core/theme/glass_palette.dart';
import 'figma_icon.dart';

/// Figma 체크 행(Login 1134:6104): `check_box`/`check_box_outline_blank` 24 +
/// 4 + 라벨 14/500 `#3C3C3C`. 켜짐 `#C00306`, 꺼짐 `#B4AEAE`. 행 높이 24.
class VivaCheckRow extends StatelessWidget {
  const VivaCheckRow(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Semantics(
      checked: value,
      label: label,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FigmaIcon.tinted(
              value
                  ? 'redesign_v2/check_box_400'
                  : 'redesign_v2/check_box_outline_blank_400',
              size: 24,
              color: value ? glass.navSelected : glass.deviceOff),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  height: 16.71 / 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.28,
                  color: glass.textSecondary)),
        ]),
      ),
    );
  }
}
