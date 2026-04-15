import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';

/// 앱 전체에서 사용하는 통일된 태그 칩
class AppTag extends StatelessWidget {
  final String label;
  final Color? color;

  const AppTag({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final tagColor = color ?? AppStyles.tagColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppStyles.chipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tagColor,
        ),
      ),
    );
  }
}
