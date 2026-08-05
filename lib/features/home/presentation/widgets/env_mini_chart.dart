import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/actuator_marker.dart';
import '../../domain/day_window.dart';
import '../home_control_providers.dart';

/// PRD §3.4 최근 24시간 실시간 차트.
///
/// 라인은 `telemetry_30m`(BE1의 `telemetry_5m`가 생기면 교체), 마커는
/// `commands`. **0값은 센서 오프라인 센티넬이라 반드시 필터**한다 — 안 걸면
/// Y축이 0까지 늘어나 곡선이 납작해진다.
///
/// 차트 영역 터치 시 통계 탭으로 이동(PRD §3.4 화면 전환 연동).
class EnvMiniChart extends ConsumerWidget {
  const EnvMiniChart({super.key});

  static const chartKey = Key('env_mini_chart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = ref.watch(chartBucketsProvider).valueOrNull ?? const [];
    final markers = ref.watch(actuatorMarkersProvider).valueOrNull ?? const [];

    final temps = [
      for (final b in buckets)
        if (b.tAvg != null && b.tAvg! > 0) b.tAvg!,
    ];
    final humids = [
      for (final b in buckets)
        if (b.hAvg != null && b.hAvg! > 0) b.hAvg!,
    ];

    final range = DayWindow.chartRange(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: InkWell(
        key: chartKey,
        onTap: () => context.go('/stats'),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppStyles.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('home_chart_title'.tr(),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppStyles.spacing8),
                SizedBox(
                  height: 64,
                  child: temps.length < 2 && humids.length < 2
                      ? Center(child: Text('home_chart_no_data'.tr()))
                      : Stack(
                          children: [
                            if (temps.length >= 2)
                              Sparkline(
                                data: temps,
                                lineColor: Colors.orange,
                                lineWidth: 2,
                              ),
                            if (humids.length >= 2)
                              Sparkline(
                                data: humids,
                                lineColor: Colors.blue,
                                lineWidth: 2,
                              ),
                            _MarkerRow(
                              markers: markers,
                              start: range.start,
                              end: range.end,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppStyles.spacing4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'home_chart_goto_stats'.tr(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.markers,
    required this.start,
    required this.end,
  });

  final List<ActuatorMarker> markers;
  final DateTime start;
  final DateTime end;

  static const _icon = {
    MarkerKind.mist: Icons.water_drop,
    MarkerKind.fan: Icons.mode_fan_off,
    MarkerKind.heater: Icons.local_fire_department,
    MarkerKind.led: Icons.lightbulb,
  };

  static const _color = {
    MarkerKind.mist: Colors.lightBlue,
    MarkerKind.fan: Colors.blueGrey,
    MarkerKind.heater: Colors.deepOrange,
    MarkerKind.led: Colors.amber,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            for (final m in markers)
              if (m.positionIn(start: start, end: end) case final p?)
                Positioned(
                  left: (p * c.maxWidth).clamp(0.0, c.maxWidth - 10),
                  bottom: 0,
                  child: Icon(_icon[m.kind], size: 10, color: _color[m.kind]),
                ),
          ],
        );
      },
    );
  }
}
