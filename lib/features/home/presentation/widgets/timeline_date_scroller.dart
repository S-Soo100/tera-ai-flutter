import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/day_window.dart';
import '../../domain/timeline_summary.dart';
import '../home_timeline_providers.dart';

/// PRD §3.5 날짜 스크롤러 + 이벤트 필터 칩.
class TimelineDateScroller extends ConsumerWidget {
  const TimelineDateScroller({super.key});

  static const nextKey = Key('timeline_next_day');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(timelineDateProvider);
    final today = DayWindow.of(DateTime.now()).labelDate;
    final canGoNext = date.isBefore(today);
    final counts =
        ref.watch(timelineFilterCountsProvider).valueOrNull ?? const {};
    final selected = ref.watch(timelineFilterProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref.read(timelineDateProvider.notifier).state =
                  date.subtract(const Duration(days: 1)),
            ),
            Text(
              DateFormat('yyyy.MM.dd').format(date) +
                  (date == today ? ' ${'home_date_today'.tr()}' : ''),
            ),
            IconButton(
              key: nextKey,
              icon: const Icon(Icons.chevron_right),
              // 미래 날짜로는 못 간다.
              onPressed: canGoNext
                  ? () => ref.read(timelineDateProvider.notifier).state =
                      date.add(const Duration(days: 1))
                  : null,
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
            children: [
              for (final f in TimelineFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppStyles.spacing8),
                  child: FilterChip(
                    // Figma Asset의 Chip은 `[카운트] [라벨]` 2요소다
                    // (`3 움직임`, `0 탈피`). 0건도 숨기지 않는다 — "없다"는
                    // 사실 자체가 정보이고, PRD §3.5의 비활성 규칙과도 맞는다.
                    label: Text(
                      '${counts[f] ?? 0} ${'home_filter_${f.name}'.tr()}',
                    ),
                    selected: selected == f,
                    // 0건이어도 칩을 없애지 않는다 — 없애면 "지원 안 하는 기능"
                    // 으로 오해한다. 비활성으로 남긴다(PRD §3.5).
                    onSelected: (counts[f] ?? 0) == 0
                        ? null
                        : (_) =>
                            ref.read(timelineFilterProvider.notifier).state = f,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
