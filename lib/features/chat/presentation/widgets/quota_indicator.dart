import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/chat_repository.dart';
import '../chat_providers.dart';

class QuotaIndicator extends ConsumerWidget {
  const QuotaIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(remainingMessagesProvider);
    final total = ChatRepository.dailyLimit;
    final ratio = total > 0 ? remaining / total : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    final Color barColor;
    if (remaining <= 0) {
      barColor = colorScheme.error;
    } else if (remaining <= 5) {
      barColor = colorScheme.tertiary;
    } else {
      barColor = colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '$remaining/$total',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
