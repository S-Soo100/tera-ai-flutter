import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/device_command.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../cage_control_actions.dart';
import '../home_control_providers.dart';

/// PRD §3.4 IoT 퀵 제어판 (2x2 Grid).
class QuickControlGrid extends ConsumerWidget {
  const QuickControlGrid({super.key});

  static const mistKey = Key('quick_control_mist');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final lock = ref.watch(mistLockProvider(deviceId));
    final brightness = ref.watch(ledBrightnessProvider);
    final mistLocked = lock.isLocked(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppStyles.spacing8,
        crossAxisSpacing: AppStyles.spacing8,
        childAspectRatio: 2.4,
        children: [
          _Tile(
            label: 'module_actuator_fan'.tr(),
            value: _stateLabel(t?.fan),
            icon: Icons.mode_fan_off,
            enabled: online,
            onTap: () =>
                sendCageCommand(context, ref, deviceId, CommandAction.fanToggle),
          ),
          _Tile(
            label: 'module_actuator_heater'.tr(),
            value: _stateLabel(t?.heaterState),
            icon: Icons.local_fire_department,
            enabled: online,
            onTap: () => handleHeaterTap(context, ref, deviceId, t),
          ),
          _Tile(
            label: 'module_actuator_led'.tr(),
            value: '$brightness%',
            icon: Icons.lightbulb_outline,
            enabled: online,
            onTap: () => openBrightnessSheet(context, ref, deviceId),
          ),
          _Tile(
            key: mistKey,
            label: 'home_mist_once'.tr(),
            // 남은 초를 표시하지 않는다. build 시점 값이라 매초 갱신되지 않아
            // 멈춘 숫자를 보여주게 된다 — 없는 편이 정직하다.
            value: mistLocked ? 'home_mist_cooldown_short'.tr() : '',
            icon: Icons.water_drop_outlined,
            enabled: online && !mistLocked,
            onTap: () => mistOnce(context, ref, deviceId),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(ActuatorState? s) {
    switch (s) {
      case ActuatorState.on:
        return 'ON';
      case ActuatorState.off:
        return 'OFF';
      default:
        return '--';
    }
  }

}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppStyles.cardRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: enabled ? null : Theme.of(context).disabledColor),
            const SizedBox(height: AppStyles.spacing4),
            Text(
              value.isEmpty ? label : '$label $value',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: enabled ? null : Theme.of(context).disabledColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
