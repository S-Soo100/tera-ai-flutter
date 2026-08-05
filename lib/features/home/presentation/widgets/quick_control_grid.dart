import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/device_command.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/mist_lock.dart';
import '../home_control_providers.dart';

/// 분무 중복 클릭 락.
final mistLockProvider =
    StateProvider<MistLock>((ref) => const MistLock(lockedUntil: null));

/// LED 밝기(0~100). BE3 전까지 펌웨어가 payload를 무시할 수 있다.
final ledBrightnessProvider = StateProvider<int>((ref) => 70);

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
    final lock = ref.watch(mistLockProvider);
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
            onTap: () => _send(ref, deviceId, CommandAction.fanToggle),
          ),
          _Tile(
            label: 'module_actuator_heater'.tr(),
            value: _stateLabel(t?.heaterState),
            icon: Icons.local_fire_department,
            enabled: online,
            onTap: () => _send(ref, deviceId, CommandAction.heaterToggle),
          ),
          _Tile(
            label: 'module_actuator_led'.tr(),
            value: '$brightness%',
            icon: Icons.lightbulb_outline,
            enabled: online,
            onTap: () => _openBrightness(context, ref, deviceId),
          ),
          _Tile(
            key: mistKey,
            label: 'home_mist_once'.tr(),
            value: mistLocked
                ? 'home_mist_cooldown'
                    .tr(args: ['${lock.remaining(DateTime.now()).inSeconds}'])
                : '',
            icon: Icons.water_drop_outlined,
            enabled: online && !mistLocked,
            onTap: () => _mist(context, ref, deviceId),
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

  Future<void> _send(
      WidgetRef ref, String deviceId, CommandAction action) async {
    await ref.read(moduleCommandSenderProvider.notifier).send(deviceId, action);
  }

  /// 1회 즉시 분사.
  ///
  /// BE2(`relay_pulse`)가 없으므로 `relay_toggle`을 **1회만** 보낸다.
  /// 앱에서 ON→지연 OFF로 펄스를 흉내내면 앱이 백그라운드로 가는 순간 펌프가
  /// 계속 돈다 — 절대 하지 않는다.
  Future<void> _mist(
      BuildContext context, WidgetRef ref, String deviceId) async {
    ref.read(mistLockProvider.notifier).state =
        MistLock.startingAt(DateTime.now());
    try {
      await _send(ref, deviceId, CommandAction.relayToggle);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_mist_sent'.tr())),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_mist_failed'.tr())),
      );
    }
  }

  Future<void> _openBrightness(
      BuildContext context, WidgetRef ref, String deviceId) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        var v = ref.read(ledBrightnessProvider).toDouble();
        return StatefulBuilder(
          builder: (ctx, setLocal) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppStyles.spacing16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('home_led_brightness'.tr(args: ['${v.round()}'])),
                  Slider(
                    value: v,
                    max: 100,
                    divisions: 20,
                    onChanged: (n) => setLocal(() => v = n),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(v.round()),
                    child: Text('common_confirm'.tr()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    ref.read(ledBrightnessProvider.notifier).state = picked;
    await ref.read(moduleCommandSenderProvider.notifier).send(
          deviceId,
          picked == 0 ? CommandAction.ledOff : CommandAction.ledOn,
          payload: {'brightness': picked},
        );
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
