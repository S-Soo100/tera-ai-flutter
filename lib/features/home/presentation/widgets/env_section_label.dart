import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';

/// 홈 온습도 카드의 섹션 라벨 — 애플 날씨 카드 좌상단의 작은 아이콘+대문자
/// 라벨 자리. "이번 주" / "지난 24시간"이 이걸 쓴다.
class EnvSectionLabel extends StatelessWidget {
  const EnvSectionLabel({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;

  /// 오른쪽 끝 장식(예: 통계로 가는 chevron).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Row(
      children: [
        Icon(icon, size: 13, color: glass.textSecondary),
        const SizedBox(width: AppStyles.spacing4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: glass.sectionLabel.copyWith(letterSpacing: 0.4),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
