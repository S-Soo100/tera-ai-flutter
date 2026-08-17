import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/stat_row.dart';
import '../home_timeline_providers.dart';

/// 타임라인 요약. 기획안 §4.1.5.
///
/// **집계 창은 밤(22:00~06:00)** — §3.1 ②. 아래 클립 목록은 당일 전체(07~07)라
/// 구간이 다르므로, 기준을 밝히지 않으면 숫자와 목록이 안 맞는 것처럼 보인다.
class TimelineSummaryChips extends ConsumerWidget {
  const TimelineSummaryChips({super.key});

  static const captionKey = Key('timeline_summary_caption');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timelineSummaryProvider).valueOrNull;
    if (s == null) return const SizedBox(height: 64);

    return StatRow(
      caption: const _NightCaption(),
      items: [
        StatItem(
          label: 'home_chip_moving'.tr(),
          value: _hours(s.movingSeconds),
          isZero: s.movingSeconds == 0,
        ),
        StatItem(
          label: 'home_chip_resting'.tr(),
          value: _hours(s.restingSeconds),
          isZero: s.restingSeconds == 0,
        ),
        StatItem(
          label: 'home_chip_eating'.tr(),
          value: 'home_count'.tr(namedArgs: {'n': '${s.eatCount}'}),
          isZero: s.eatCount == 0,
        ),
        StatItem(
          label: 'home_chip_drinking'.tr(),
          value: 'home_count'.tr(namedArgs: {'n': '${s.drinkCount}'}),
          isZero: s.drinkCount == 0,
        ),
      ],
    );
  }

  static String _hours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return 'home_minutes'.tr(namedArgs: {'m': '$m'});
    if (m == 0) return 'home_hours'.tr(namedArgs: {'h': '$h'});
    return 'home_hours_minutes'.tr(namedArgs: {'h': '$h', 'm': '$m'});
  }
}

/// 집계 기준 표시. 차트의 밤 띠와 **같은 스와치**를 써서 "그 어두운 구간"과
/// 연결한다.
class _NightCaption extends StatelessWidget {
  const _NightCaption();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: TimelineSummaryChips.captionKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: context.glass.nightBand,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: theme.dividerColor),
          ),
        ),
        const SizedBox(width: AppStyles.spacing4),
        Text(
          'home_summary_night_basis'.tr(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
