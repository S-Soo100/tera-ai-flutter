import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/env_extremes.dart';
import '../home_control_providers.dart';

/// PRD §3.4 실시간 온습도 카드 — 현재값 + 당일 최고/최저.
class LiveEnvCard extends ConsumerWidget {
  const LiveEnvCard({super.key});

  static const cardKey = Key('live_env_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(todayExtremesProvider).valueOrNull;

    return Card(
      key: cardKey,
      margin: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'home_env_temp_now'
                      .tr(args: [t?.tA?.toStringAsFixed(1) ?? '--']),
                  style: AppStyles.subsectionTitle(context),
                ),
                Text(
                  'home_env_humid_now'
                      .tr(args: [t?.hA?.toStringAsFixed(0) ?? '--']),
                  style: AppStyles.subsectionTitle(context),
                ),
              ],
            ),
            if (ex != null && ex.hasData) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                _extremesLine(ex),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _extremesLine(EnvExtremes ex) {
    final parts = <String>[];
    if (ex.tempMax != null && ex.tempMin != null) {
      parts.add('home_env_temp_range'.tr(args: [
        ex.tempMax!.toStringAsFixed(1),
        ex.tempMin!.toStringAsFixed(1),
      ]));
    }
    if (ex.humidMax != null && ex.humidMin != null) {
      parts.add('home_env_humid_range'.tr(args: [
        ex.humidMax!.toStringAsFixed(0),
        ex.humidMin!.toStringAsFixed(0),
      ]));
    }
    return parts.join(' · ');
  }
}
