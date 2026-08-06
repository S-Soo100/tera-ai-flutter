import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/device_command.dart';
import '../../../my_cage/domain/telemetry_reading.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../../my_cage/presentation/widgets/heater_lock_dialog.dart';
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
            onTap: () =>
                _send(context, ref, deviceId, CommandAction.fanToggle),
          ),
          _Tile(
            label: 'module_actuator_heater'.tr(),
            value: _stateLabel(t?.heaterState),
            icon: Icons.local_fire_department,
            enabled: online,
            onTap: () => _handleHeaterTap(context, ref, deviceId, t),
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

  /// 명령 1건 발행. **실패를 삼키지 않는다.**
  ///
  /// onTap은 VoidCallback이라 여기서 던지면 unhandled async error로 콘솔에만
  /// 남고 사용자는 "눌렀는데 아무 일도 안 일어남"을 기기 고장으로 오해한다.
  /// 그래서 여기서 잡아 토스트로 알린다.
  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    String deviceId,
    CommandAction action, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      await ref
          .read(moduleCommandSenderProvider.notifier)
          .send(deviceId, action, payload: payload);
    } catch (e, st) {
      debugPrint('[cage-control] $action failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('module_command_failed'.tr())),
      );
    }
  }

  /// PRD §3.4 히터 제어 — **안전 확인을 거친다.**
  ///
  /// 히터는 과열 시 개체 폐사로 이어지는 유일한 액추에이터다. 기존
  /// `actuator_controls.dart`의 2단 안전 플로우를 그대로 따른다:
  /// ① 안전잠금(DS18B20 50°C 초과/통신오류)이 걸려 있으면 해제 다이얼로그부터
  /// ② 아니면 조작 확인 다이얼로그를 받고 나서 전송
  ///
  /// 홈이 주 제어면이 된 이상 이 경로에도 같은 장치가 있어야 한다.
  Future<void> _handleHeaterTap(
    BuildContext context,
    WidgetRef ref,
    String deviceId,
    TelemetryReading? telemetry,
  ) async {
    if (telemetry?.heaterLocked ?? false) {
      await showHeaterLockDialog(context, ref, deviceId: deviceId);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('module_heater_confirm_title'.tr()),
        content: Text('module_heater_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('module_heater_confirm_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
            ),
            child: Text('module_heater_confirm_yes'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _send(context, ref, deviceId, CommandAction.heaterToggle);
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
      await ref
          .read(moduleCommandSenderProvider.notifier)
          .send(deviceId, CommandAction.relayToggle);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_mist_sent'.tr())),
      );
    } catch (e, st) {
      debugPrint('[cage-control] mist failed: $e\n$st');
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
    if (picked == null || !context.mounted) return;
    ref.read(ledBrightnessProvider.notifier).state = picked;
    await _send(
      context,
      ref,
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
