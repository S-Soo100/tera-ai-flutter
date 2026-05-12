import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';

class EnvironmentCard extends StatelessWidget {
  const EnvironmentCard({super.key});

  static const double _dummyTemp = 24.5;
  static const double _dummyHumidity = 68;

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('environment_coming_soon'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──────────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'environment_card_title'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppStyles.spacing8,
                    vertical: AppStyles.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppStyles.chipRadius),
                  ),
                  child: Text(
                    'environment_demo_badge'.tr(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppStyles.spacing4),
            Text(
              'environment_card_target'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppStyles.spacing16),

            // ── 온도 / 습도 박스 ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _SensorBox(
                    icon: Icons.thermostat,
                    labelKey: 'environment_current_temp',
                    value: '${_dummyTemp.toStringAsFixed(1)}°',
                  ),
                ),
                const SizedBox(width: AppStyles.spacing12),
                Expanded(
                  child: _SensorBox(
                    icon: Icons.water_drop,
                    labelKey: 'environment_current_humidity',
                    value: '${_dummyHumidity.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppStyles.spacing16),

            // ── 액션 버튼 ─────────────────────────────────────────────────
            Wrap(
              spacing: AppStyles.spacing8,
              runSpacing: AppStyles.spacing8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.air, size: 18),
                  label: Text('environment_action_ventilate'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.water_drop_outlined, size: 18),
                  label: Text('environment_action_water'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text('environment_action_settings'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 센서 값 표시 박스 ────────────────────────────────────────────────────────

class _SensorBox extends StatelessWidget {
  const _SensorBox({
    required this.icon,
    required this.labelKey,
    required this.value,
  });

  final IconData icon;
  final String labelKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppStyles.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: AppStyles.spacing4),
              Text(
                labelKey.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.spacing8),
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
