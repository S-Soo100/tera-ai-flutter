import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/env_summary_bar.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/stats_metric.dart';
import '../stats_providers.dart';

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

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(chartExtremesProvider).valueOrNull;
    final scrub = ref.watch(statsScrubProvider);
    final data = ref.watch(envChartDataProvider).valueOrNull;
    final metrics = ref.watch(statsMetricsProvider);

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
      onClearScrub: () => ref.read(statsScrubProvider.notifier).state = null,
    );
  }
}
