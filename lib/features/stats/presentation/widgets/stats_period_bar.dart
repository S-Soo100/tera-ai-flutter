import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/stats_metric.dart';
import '../../domain/stats_period.dart';
import '../stats_providers.dart';

/// 기간 선택 `[일간] [주간] [월간]`. 기획안 §4.3.1.
///
/// **아직 못 그리는 기간도 고를 수 있게 둔다.** 비활성으로 막으면 "이 앱은
/// 주간을 안 보여준다"로 읽히는데, 실제로는 디자인 대기일 뿐이다. 고르면
/// 그 자리에 무엇이 들어올지 설명하는 자리표시자가 나온다.
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  static const barKey = Key('stats_period_bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statsPeriodProvider);

    return Padding(
      key: barKey,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: SegmentedButton<StatsPeriod>(
        segments: [
          for (final p in StatsPeriod.values)
            ButtonSegment(value: p, label: Text(p.labelKey.tr())),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (s) =>
            ref.read(statsPeriodProvider.notifier).state = s.first,
      ),
    );
  }
}

/// 메트릭 필터 칩. 기획안 §4.3.2 — 다중 선택.
///
/// 켠 지표만 차트에 그려진다. **동작하지 않는 필터를 두지 않는다** — 눌러도
/// 아무 일이 없으면 사용자는 화면이 고장 났다고 판단한다.
class StatsMetricFilter extends ConsumerWidget {
  const StatsMetricFilter({super.key});

  static const filterKey = Key('stats_metric_filter');

  /// 칩 하나를 집는 키. 문구가 아니라 지표로 집어야 다국어에서도 안 깨진다.
  static Key metricKey(StatsMetric m) => Key('stats_metric_chip_${m.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(statsMetricsProvider);

    return SizedBox(
      key: filterKey,
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
        children: [
          for (final m in StatsMetric.values) ...[
            FilterChip(
              key: metricKey(m),
              label: Text(m.labelKey.tr()),
              selected: metrics.contains(m),
              // 비활성 지표는 눌리지 않되 **목록에는 남는다**(기획안 §4.3.2).
              onSelected: m.isReady
                  ? (_) => ref.read(statsMetricsProvider.notifier).state =
                      toggleMetric(metrics, m)
                  : null,
              tooltip: m.isReady ? null : 'stats_metric_not_ready'.tr(),
            ),
            const SizedBox(width: AppStyles.spacing8),
          ],
        ],
      ),
    );
  }
}
