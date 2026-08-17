import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/glass_chip.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';
import '../../domain/stats_metric.dart';
import '../../domain/stats_period.dart';
import '../stats_providers.dart';

/// 기간 선택 `[일간] [주간] [월간]`. 기획안 §4.3.1.
///
/// **아직 못 그리는 기간도 고를 수 있게 둔다.** 비활성으로 막으면 "이 앱은
/// 주간을 안 보여준다"로 읽히는데, 실제로는 디자인 대기일 뿐이다. 고르면
/// 그 자리에 무엇이 들어올지 설명하는 자리표시자가 나온다.
///
/// 표면은 홈 서브탭과 같은 [GlassSegmentedControl] — 선택 로직은 불변.
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  static const barKey = Key('stats_period_bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statsPeriodProvider);

    return Padding(
      key: barKey,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: GlassSegmentedControl<StatsPeriod>(
        segments: [
          for (final p in StatsPeriod.values)
            GlassSegment(value: p, label: p.labelKey.tr()),
        ],
        selected: selected,
        onChanged: (p) {
          ref.read(statsPeriodProvider.notifier).state = p;
          // 스크럽 위치(0~1)는 **창에 상대적**이다 — 기간을 바꾸면 같은 x가
          // 전혀 다른 시각을 가리키므로 남겨두면 거짓 값을 보여준다.
          ref.read(statsScrubProvider.notifier).state = null;
        },
      ),
    );
  }
}

/// 메트릭 필터 칩. 기획안 §4.3.2 — 다중 선택.
///
/// 켠 지표만 차트에 그려진다. **동작하지 않는 필터를 두지 않는다** — 눌러도
/// 아무 일이 없으면 사용자는 화면이 고장 났다고 판단한다.
///
/// 표면은 유리 캡슐([GlassChip]) — 켠 지표는 불투명 흰 알약(A안 활성 문법),
/// 끈 지표는 유리, 준비 안 된 지표는 흐린 유리 + 툴팁. 토글 로직은 불변.
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
        padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
        children: [
          for (final m in StatsMetric.values) ...[
            _MetricChip(
              key: metricKey(m),
              metric: m,
              selected: metrics.contains(m),
              // 비활성 지표는 눌리지 않되 **목록에는 남는다**(기획안 §4.3.2).
              onTap: m.isReady
                  ? () => ref.read(statsMetricsProvider.notifier).state =
                      toggleMetric(metrics, m)
                  : null,
            ),
            const SizedBox(width: AppStyles.spacing8),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    super.key,
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  final StatsMetric metric;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ready = metric.isReady;
    final on = selected && ready;

    final glass = context.glass;
    final Color fg;
    if (!ready) {
      fg = glass.textTertiary;
    } else if (on) {
      fg = glass.textOnActive;
    } else {
      fg = glass.textSecondary;
    }

    final chip = GlassChip(
      overlay:
          !ready ? glass.overlayFaint : (on ? glass.activeTile : glass.overlay),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        metric.labelKey.tr(),
        style: glass.tileTitle.copyWith(
          fontSize: 13,
          color: fg,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    if (ready) return chip;
    return Tooltip(message: 'stats_metric_not_ready'.tr(), child: chip);
  }
}
