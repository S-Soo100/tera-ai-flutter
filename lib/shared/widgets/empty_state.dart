import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';

/// 데이터가 없을 때. 디자인 시스템 `Components / EmptyState`.
///
/// **빈 화면은 고장으로 읽힌다.** 무엇이 없는지, 왜 없는지, (있다면) 무엇을 할
/// 수 있는지를 말한다.
///
/// 문구는 시스템이 아니라 **사용자 쪽에서** 쓴다 —
/// `표시할 데이터가 없어요`(시스템) → `아직 기록된 온습도가 없어요`(사용자).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  /// 무엇이 없는지. 한 줄.
  final String title;

  /// 왜 없는지 / 어떻게 채워지는지.
  final String? description;

  /// 사용자가 할 수 있는 일이 있을 때만 준다. 없으면 버튼을 만들지 않는다 —
  /// 누를 데 없는 버튼은 막다른 길이다.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing24,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
          // 점선이 없으므로 실선을 옅게 — 카드처럼 보이면 "내용이 있는 영역"
          // 으로 오해된다.
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppStyles.spacing4),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppStyles.spacing12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
