import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/env_summary_bar.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/stats_metric.dart';
import '../../domain/stats_period.dart';
import '../stats_providers.dart';
import '../weekly_providers.dart';

/// 통계 탭 요약 바 — 공용 [EnvSummaryBar]에 이 화면의 상태를 물린다.
///
/// 홈과 다른 점은 **스크러버뿐**이다. 스크럽 중이면 그 시점의 값으로 바뀌고,
/// ✕로 현재값·최고/최저로 돌아온다.
class StatsSummaryBar extends ConsumerWidget {
  const StatsSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    // 최고/최저는 **바로 아래 그래프가 보여주는 구간**의 값이어야 한다.
    // 기간을 바꿨는데 숫자가 그대로면 둘이 다른 이야기를 하게 된다.
    final weekly = ref.watch(statsPeriodProvider) == StatsPeriod.weekly;

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = (weekly
            ? ref.watch(weeklyExtremesProvider)
            : ref.watch(chartExtremesProvider))
        .valueOrNull;
    final scrub = ref.watch(statsScrubProvider);
    final data = (weekly
            ? ref.watch(weeklyChartDataProvider)
            : ref.watch(envChartDataProvider))
        .valueOrNull;
    final metrics = ref.watch(statsMetricsProvider);
    // 스크럽 시각 표기는 차트 X축과 같은 형식을 따른다 — 주간은 날짜(8/6),
    // 일간은 시:분. 창(window)이 형식의 단일 출처다.
    final window = weekly
        ? ref.watch(weeklyWindowProvider)
        : ref.watch(chartWindowProvider);

    // 데이터가 없으면 스크럽 값을 만들 수 없다 — 시각만 띄우면 거짓말이 된다.
    final showScrub = scrub != null && data != null;

    return EnvSummaryBar(
      temperature: t?.tA,
      humidity: t?.hA,
      extremes: ex,
      scrubX: showScrub ? scrub : null,
      scrubAt: showScrub ? data.timeAt(scrub) : null,
      // 꺼진 지표는 스크럽 표시에서도 빠진다.
      scrubTemperature: showScrub && metrics.contains(StatsMetric.temperature)
          ? data.tempAt(scrub)
          : null,
      scrubHumidity: showScrub && metrics.contains(StatsMetric.humidity)
          ? data.humidAt(scrub)
          : null,
      scrubFormat: window.format,
      onClearScrub: () => ref.read(statsScrubProvider.notifier).state = null,
      // 주간은 극값 라벨에 기간을 명시한다 — 현재값(실시간) 옆에 "최고 33°"만
      // 있으면 그것도 지금 이야기처럼 읽힌다.
      extremesTempKey:
          weekly ? 'stats_extremes_temp_weekly' : 'stats_extremes_temp',
      extremesHumidKey:
          weekly ? 'stats_extremes_humid_weekly' : 'stats_extremes_humid',
    );
  }
}
