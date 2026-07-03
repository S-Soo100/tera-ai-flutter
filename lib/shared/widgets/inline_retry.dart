import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 컴팩트한 인라인 재시도 (새로고침 아이콘 + "다시 시도"). 카드·섹션 에러 자리에
/// 둔다. 여러 화면에 흩어진 인라인 에러 재시도를 한 곳으로 통일하기 위한 공용 위젯.
class InlineRetry extends StatelessWidget {
  const InlineRetry({
    super.key,
    required this.onRetry,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
  });

  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              'retry'.tr(),
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
