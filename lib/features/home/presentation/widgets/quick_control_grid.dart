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
///
/// **사육장 제어의 유일한 진입점**이다. 한때 라이브 바로 아래 같은 4종을 담은
/// 컴팩트 바를 얹었다가 한 화면에 버튼이 두 벌 쌓여 걷어냈다(2026-08-09).
/// 다시 두 벌로 만들지 말 것 — 어느 쪽을 눌러야 하는지 매번 판단하게 된다.
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
    final mistDuration = ref.watch(mistDurationProvider);
    final mistLocked = lock.isLocked(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppStyles.spacing8,
        crossAxisSpacing: AppStyles.spacing8,
        childAspectRatio: 3.0,
        children: [
          _Tile(
            label: 'module_actuator_fan'.tr(),
            value: _stateLabel(t?.fan),
            icon: Icons.mode_fan_off,
            enabled: online,
            active: t?.fan == ActuatorState.on,
            onTap: () => sendCageCommand(
                context, ref, deviceId, CommandAction.fanToggle),
          ),
          _Tile(
            label: 'module_actuator_heater'.tr(),
            value: _stateLabel(t?.heaterState),
            icon: Icons.local_fire_department,
            enabled: online,
            active: t?.heaterState == ActuatorState.on,
            onTap: () => handleHeaterTap(context, ref, deviceId, t),
          ),
          _Tile(
            label: 'module_actuator_led'.tr(),
            value: '$brightness%',
            icon: Icons.lightbulb_outline,
            // terra-server 계약에 LED 상태 telemetry가 없다(메모리
            // project_led_control_gap). 모르는 것을 켜진 것처럼 칠하지 않는다.
            enabled: online,
            active: false,
            onTap: () => openBrightnessSheet(context, ref, deviceId),
          ),
          _Tile(
            key: mistKey,
            label: 'home_mist_once'.tr(),
            // 남은 초를 표시하지 않는다. build 시점 값이라 매초 갱신되지 않아
            // 멈춘 숫자를 보여주게 된다 — 없는 편이 정직하다.
            // 쿨다운이 아닐 때는 마지막에 고른 분사 시간을 띄운다.
            value: mistLocked
                ? 'home_mist_cooldown_short'.tr()
                : 'home_mist_seconds'.tr(args: ['${mistDuration.seconds}']),
            icon: Icons.water_drop_outlined,
            enabled: online && !mistLocked,
            // 1회성 동작이라 '켜진 상태'가 없다.
            active: false,
            onTap: () => openMistSheet(context, ref, deviceId),
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

/// 제어 타일. Figma Button 규격을 따른다 — 켜짐은 **메인컬러 채움**,
/// 꺼짐은 흰 바탕 + 라인컬러 테두리(§4.3).
///
/// 상태를 텍스트(`ON`/`OFF`)로만 구분하면 훑어볼 때 안 읽힌다. 색으로 먼저
/// 보이고 글자가 확인해주는 순서여야 한다.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;

  /// 기기가 켜져 있는가. 채움 여부를 가른다.
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;
    if (!enabled) {
      bg = scheme.surfaceContainerLow;
      fg = Theme.of(context).disabledColor;
    } else if (active) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else {
      bg = scheme.surfaceContainerLowest;
      fg = scheme.onSurface;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppStyles.cardRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppStyles.spacing12,
            vertical: AppStyles.spacing8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            border: active && enabled
                ? null
                : Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppStyles.spacing8),
              Expanded(
                // 그리드 셀 높이가 고정이라 큰 글씨 설정에서 두 줄이 넘친다.
                // 잘라내는 대신 비율을 유지한 채 줄인다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (value.isNotEmpty)
                        Text(
                          value,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: fg.withValues(alpha: 0.7),
                                  ),
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
