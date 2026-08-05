import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../home_timeline_providers.dart';

/// PRD §3.5 당일 요약 칩 (Horizontal Chips).
class TimelineSummaryChips extends ConsumerWidget {
  const TimelineSummaryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timelineSummaryProvider).valueOrNull;
    if (s == null) return const SizedBox(height: 56);

    final items = <(String, String)>[
      ('home_chip_moving', _hours(s.movingSeconds)),
      ('home_chip_resting', _hours(s.restingSeconds)),
      ('home_chip_eating', '${s.eatCount}회'),
      ('home_chip_drinking', '${s.drinkCount}회'),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppStyles.spacing8),
        itemBuilder: (_, i) => Chip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(items[i].$1.tr(),
                  style: Theme.of(context).textTheme.labelSmall),
              Text(items[i].$2,
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }

  static String _hours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m분';
    return m == 0 ? '$h시간' : '$h시간 $m분';
  }
}
