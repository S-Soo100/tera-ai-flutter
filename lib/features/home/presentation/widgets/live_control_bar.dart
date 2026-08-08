import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/device_command.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/device_mode.dart';
import '../cage_control_actions.dart';
import '../home_control_providers.dart';
import '../home_set_providers.dart';

/// 라이브 영상 바로 아래 붙는 컴팩트 IoT 제어 바.
///
/// 배경: Figma 피드백 "캠을 보면서 IoT 기능을 조작할 수 있도록 버튼이 캠 아래
/// 작게 있으면 좋을듯 — 분무 on/off, 환기팬 on/off, LED on/off 등"
/// (`docs/figma-final-design-transcript.md` §2.1 크레캠, 대조표 F1).
///
/// PRD §3.3의 서브탭 구조는 **그대로 두고** 이 바만 위에 얹었다. 서브탭을 없애면
/// 타임라인(무한 스크롤)이 제어를 계속 아래로 밀어내고, `IndexedStack`의 지연
/// 빌드 최적화도 함께 버려야 한다.
///
/// 여기는 **즉시 토글만** 담당한다. LED 밝기 슬라이더·히터 안전 확인 같은 상세
/// 조작은 서브탭의 [QuickControlGrid]와 **같은 함수**(`cage_control_actions.dart`)를
/// 호출한다 — 히터 안전 플로우를 우회하는 경로를 만들지 않기 위함이다.
///
/// **통합 세트(캠 + 제어기)에서만 노출**한다. 사육장 단품은 위에 라이브가 없어
/// "캠을 보면서"가 성립하지 않고, 캠 단품은 제어할 기기 자체가 없다.
class LiveControlBar extends ConsumerWidget {
  const LiveControlBar({super.key});

  static const barKey = Key('live_control_bar');
  static const mistKey = Key('live_control_bar_mist');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(currentDeviceModeProvider).valueOrNull;
    if (mode != DeviceMode.integrated) return const SizedBox.shrink();

    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final mistLocked =
        ref.watch(mistLockProvider(deviceId)).isLocked(DateTime.now());

    // 라이브 면과 같은 색을 깔아 **하나의 덩어리**로 읽히게 한다. 밝은 배경에
    // 아이콘만 띄우면 라이브와 서브탭 사이에 떠 있는 무국적 조각이 된다.
    return Container(
      key: barKey,
      color: AppTheme.liveSurface,
      padding: const EdgeInsets.only(
        left: AppStyles.spacing8,
        right: AppStyles.spacing8,
        top: AppStyles.spacing4,
        bottom: AppStyles.spacing12,
      ),
      // 4개가 폭을 균등 분할한다. 자연 크기로 두면 라벨이 긴 언어·좁은 기기에서
      // Row가 넘친다(실제로 테스트에서 179px 오버플로로 잡혔다).
      child: Row(
        children: [
          _CompactControl(
            label: 'module_actuator_fan'.tr(),
            icon: Icons.mode_fan_off,
            active: t?.fan == ActuatorState.on,
            enabled: online,
            onTap: () => sendCageCommand(
                context, ref, deviceId, CommandAction.fanToggle),
          ),
          _CompactControl(
            label: 'module_actuator_heater'.tr(),
            icon: Icons.local_fire_department,
            active: t?.heaterState == ActuatorState.on,
            enabled: online,
            onTap: () => handleHeaterTap(context, ref, deviceId, t),
          ),
          _CompactControl(
            label: 'module_actuator_led'.tr(),
            icon: Icons.lightbulb_outline,
            // terra-server 계약에 LED 상태 telemetry가 없어 켜짐 여부를 모른다
            // (메모리 `project_led_control_gap`). 모르는 것을 켜진 것처럼
            // 칠하지 않는다.
            active: false,
            enabled: online,
            onTap: () => openBrightnessSheet(context, ref, deviceId),
          ),
          _CompactControl(
            key: mistKey,
            label: 'home_mist_once'.tr(),
            icon: Icons.water_drop_outlined,
            active: false,
            enabled: online && !mistLocked,
            onTap: () => mistOnce(context, ref, deviceId),
          ),
        ],
      ),
    );
  }
}

class _CompactControl extends StatelessWidget {
  const _CompactControl({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 어두운 라이브 면 위에 놓이므로 테마 전경색을 쓰지 않는다.
    // 켜짐은 흰색으로 또렷하게, 꺼짐은 반투명 흰색, 못 누르면 더 흐리게.
    final Color fg;
    if (!enabled) {
      fg = Colors.white.withValues(alpha: 0.28);
    } else if (active) {
      fg = Colors.white;
    } else {
      fg = Colors.white.withValues(alpha: 0.62);
    }

    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppStyles.spacing4,
            vertical: AppStyles.spacing4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
