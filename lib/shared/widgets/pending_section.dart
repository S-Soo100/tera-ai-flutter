import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';

/// 아직 만들지 않은 섹션의 자리. 디자인 시스템 `Components / PendingSection`.
///
/// **[EmptyState]와 뜻이 다르다.** EmptyState는 *"기능은 있는데 데이터가
/// 없다"*, 이쪽은 *"기능 자체가 아직 없다"*다. 둘을 같은 모양으로 그리면
/// 사용자가 자기 데이터가 사라진 줄 안다.
///
/// **무엇이 들어올 자리인지 반드시 쓴다.** 회색 상자만 있으면 고장으로
/// 읽히고, 설명이 있으면 그 자체로 검토 가능한 기획서가 된다.
class PendingSection extends StatelessWidget {
  const PendingSection({
    super.key,
    required this.title,
    required this.description,
    this.reason,
  });

  /// 이 자리에 들어올 섹션의 이름. 기획안 문구를 그대로 쓴다.
  final String title;

  /// 무엇을 보여줄 자리인지. 한 줄.
  final String description;

  /// 왜 아직 없는지. 밝힐 수 있을 때만 — *"디자인 대기"*, *"기기 제어 개발 후"*.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppStyles.spacing16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          // 채우지 않고 테두리만 — 채우면 카드로 보여서 "내용이 있는데 비었다"로
          // 읽힌다. 빈 틀이라는 게 형태로 드러나야 한다.
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600, color: muted),
                  ),
                ),
                const SizedBox(width: AppStyles.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacing8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppStyles.spacing12),
                  ),
                  child: Text('common_pending'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                ),
              ],
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text(description,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            if (reason != null) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                reason!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
