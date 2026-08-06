import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/actuator_marker.dart';
import '../../domain/env_chart_series.dart';
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

    // 온·습도를 같은 버킷 집합에서 뽑고, 마커가 쓸 시간 구간도 함께 받는다.
    // 마커 구간은 차트 요청 구간(전날 19:00~현재)이 아니라 **실제 데이터 구간**
    // 이어야 선과 같은 자리를 가리킨다 — Sparkline이 가진 데이터를 폭 100%로
    // 늘려 그리기 때문이다.
    final series = EnvChartSeries.from(buckets);

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
                  child: !series.hasLine
                      ? Center(child: Text('home_chart_no_data'.tr()))
                      : Stack(
                          children: [
                            Sparkline(
                              data: series.temps,
                              lineColor: Colors.orange,
                              lineWidth: 2,
                            ),
                            Sparkline(
                              data: series.humids,
                              lineColor: Colors.blue,
                              lineWidth: 2,
                            ),
                            _MarkerRow(
                              markers: markers,
                              start: series.from!,
                              end: series.to!,
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
