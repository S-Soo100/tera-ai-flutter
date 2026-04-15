import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';

/// 앱 전체에서 사용하는 섹션 헤더
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyles.spacing12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppStyles.sectionTitle(context)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
