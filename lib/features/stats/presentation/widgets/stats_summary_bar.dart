import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';

/// Figma 24시 화면 상단 요약 바.
///
/// 좌우 2분할로 온도·습도를 대칭 배치하고, 각 아래에 최고/최저를 작게 붙인다.
/// 최고/최저는 **당일(07:00~) 기준**([todayExtremesProvider])이다 — 차트 구간
/// (전날 19:00~현재)과 다른 창이니 혼동하지 말 것.
class StatsSummaryBar extends ConsumerWidget {
  const StatsSummaryBar({super.key});

  static const barKey = Key('stats_summary_bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(todayExtremesProvider).valueOrNull;

    return Padding(
      key: barKey,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              icon: Icons.thermostat,
              color: AppTheme.chartTemperature,
              value: 'stats_axis_temp'.tr(
                namedArgs: {'v': t?.tA?.toStringAsFixed(1) ?? '--'},
              ),
              extremes: 'stats_extremes_temp'.tr(namedArgs: {
                'max': ex?.tempMax?.toStringAsFixed(1) ?? '--',
                'min': ex?.tempMin?.toStringAsFixed(1) ?? '--',
              }),
            ),
          ),
          Expanded(
            child: _Metric(
              icon: Icons.water_drop,
              color: AppTheme.chartHumidity,
              value: 'stats_axis_humid'.tr(
                namedArgs: {'v': t?.hA?.toStringAsFixed(0) ?? '--'},
              ),
              extremes: 'stats_extremes_humid'.tr(namedArgs: {
                'max': ex?.humidMax?.toStringAsFixed(0) ?? '--',
                'min': ex?.humidMin?.toStringAsFixed(0) ?? '--',
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.value,
    required this.extremes,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String extremes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppStyles.spacing4),
            // 좌우 2분할이라 한 칸이 화면의 절반뿐이다. 큰 글씨 설정이나
            // 자릿수가 늘면 바로 넘치므로, 잘라내는 대신 비율을 유지해 줄인다
            // — 숫자는 ellipsis로 자르면 값이 달라 보인다.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppStyles.subsectionTitle(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          extremes,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
