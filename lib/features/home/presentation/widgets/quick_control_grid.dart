import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/telemetry_reading.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../cage_control_actions.dart';
import '../home_control_providers.dart';

/// PRD §3.4 IoT 퀵 제어 — B안 **가로 스크롤 캡슐 행**(2026-08-18).
///
/// 이름은 2×2 그리드 시절(A안)의 것이다. 표면만 바뀌었고 자리·역할은 같다.
///
/// **사육장 제어의 유일한 진입점**이다. 한때 라이브 바로 아래 같은 4종을 담은
/// 컴팩트 바를 얹었다가 한 화면에 버튼이 두 벌 쌓여 걷어냈다(2026-08-09).
/// 다시 두 벌로 만들지 말 것 — 어느 쪽을 눌러야 하는지 매번 판단하게 된다.
///
/// B 문법: 데이터가 주인공, 제어는 보조 — 카드 한 장 안에 `CONTROLS` 라벨 +
/// 캡슐 버튼 행. 켜짐 = **앰버 채움 + 짙은 글자**([GlassPalette.textOnActive]),
/// 꺼짐 = 테두리 캡슐, 비활성(오프라인) = 3차 텍스트색. **탭 동작은 전부
/// 기존 [cage_control_actions] 경유**(히터 2단 안전확인 포함) — 여기서 명령을
/// 직접 만들지 말 것.
class QuickControlGrid extends ConsumerWidget {
  const QuickControlGrid({super.key});

  static const mistKey = Key('quick_control_mist');
  static const fanKey = Key('quick_control_fan');
  static const heaterKey = Key('quick_control_heater');
  static const ledKey = Key('quick_control_led');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final lock = ref.watch(mistLockProvider(deviceId));
    final mistDuration = ref.watch(mistDurationProvider);
    final glass = context.glass;
    final mistLocked = lock.isLocked(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
              child: Text('home_controls_label'.tr(), style: glass.labelCaps),
            ),
            const SizedBox(height: AppStyles.spacing12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
              child: Row(
                children: [
                  _Capsule(
                    key: fanKey,
                    label: 'module_actuator_fan'.tr(),
                    value: _stateLabel(t?.fan),
                    icon: Icons.air,
                    enabled: online,
                    active: t?.fan == ActuatorState.on,
                    onTap: () => handleFanTap(context, ref, deviceId, t),
                  ),
                  const SizedBox(width: AppStyles.spacing8),
                  _Capsule(
                    key: heaterKey,
                    label: 'module_actuator_heater'.tr(),
                    value: _stateLabel(t?.heaterState),
                    icon: Icons.local_fire_department_outlined,
                    enabled: online,
                    active: t?.heaterState == ActuatorState.on,
                    onTap: () => handleHeaterTap(context, ref, deviceId, t),
                  ),
                  const SizedBox(width: AppStyles.spacing8),
                  _Capsule(
                    key: ledKey,
                    label: 'module_actuator_led'.tr(),
                    // `telemetry.led`/`led_brightness`(2026-08-18 회신 §4).
                    // 구 펌웨어는 안 보내 unavailable → 빈 값·비활성 색 —
                    // 모르는 것을 켜진 것처럼 칠하지 않는다.
                    value: _ledLabel(t),
                    icon: Icons.light_mode_outlined,
                    enabled: online,
                    active: t?.led == ActuatorState.on,
                    // 꺼져 있을 때 보고되는 0을 시드로 넘기면 슬라이더가 1%로
                    // 열린다 — 켜져 있을 때의 밝기만 넘긴다.
                    onTap: () => openLedSheet(context, ref, deviceId,
                        currentBrightness: t?.led == ActuatorState.on
                            ? t?.ledBrightness
                            : null),
                  ),
                  const SizedBox(width: AppStyles.spacing8),
                  _Capsule(
                    key: mistKey,
                    label: 'home_mist_once'.tr(),
                    // 남은 초를 표시하지 않는다. build 시점 값이라 매초 갱신되지
                    // 않아 멈춘 숫자를 보여주게 된다 — 없는 편이 정직하다.
                    // 쿨다운이 아닐 때는 마지막에 고른 분사 시간을 띄운다.
                    value: mistLocked
                        ? 'home_mist_cooldown_short'.tr()
                        : 'home_mist_seconds'
                            .tr(args: ['${mistDuration.seconds}']),
                    icon: Icons.water_drop_outlined,
                    enabled: online && !mistLocked,
                    // 1회성 동작이라 '켜진 상태'가 없다.
                    active: false,
                    onTap: () => openMistSheet(context, ref, deviceId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 켜짐 + 밝기 보고(MOSFET)면 `60%`, 아니면 ON/OFF, 모르면 빈 값.
  static String _ledLabel(TelemetryReading? t) {
    if (t == null || t.led == ActuatorState.unavailable) return '';
    if (t.led == ActuatorState.on && t.ledBrightness != null) {
      return '${t.ledBrightness}%';
    }
    return _stateLabel(t.led);
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

/// 제어 캡슐 — B안 문법.
///
/// 켜짐은 **앰버 채움 + 짙은 글자**, 꺼짐은 테두리만, 비활성은 3차 텍스트색.
/// 상태를 텍스트(`ON`/`OFF`)로만 구분하면 훑어볼 때 안 읽힌다 — 면과 색이
/// 먼저 보이고 글자가 확인해주는 순서여야 한다.
///
/// 1단계에서 발견한 "활성 아이콘 묻힘"(앰버 위 앰버 아이콘)은 아이콘·글자를
/// 전부 [GlassPalette.textOnActive]로 통일해 해소했다.
class _Capsule extends StatefulWidget {
  const _Capsule({
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

  /// 기기가 켜져 있는가. 앰버 채움 전환 여부를 가른다.
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Capsule> createState() => _CapsuleState();
}

class _CapsuleState extends State<_Capsule> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.active && widget.enabled;
    final glass = context.glass;

    final Color fg;
    final Color fgSecondary;
    if (!widget.enabled) {
      fg = glass.textTertiary;
      fgSecondary = glass.textTertiary;
    } else if (on) {
      fg = glass.textOnActive;
      fgSecondary = glass.textOnActiveSecondary;
    } else {
      fg = glass.textSecondary;
      fgSecondary = glass.textTertiary;
    }

    // 표면은 단일 AnimatedContainer 하나로 지속시킨다 — 위젯 타입을 갈아끼우면
    // element가 재생성돼 200ms 전환 없이 팝만 된다(A안 타일과 같은 교훈).
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      // 리셋은 enabled와 무관하게 **무조건** 한다. 눌림 도중 enabled가 플립돼
      // 콜백이 전부 null로 갈리면 GestureDetector가 recognizer를 dispose하며
      // build 중 cancel을 쏴서 debug 에러 로그 + 한 프레임 리빌드가 늘어난다.
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: on ? glass.activeTile : Colors.transparent,
            border: Border.all(
              color: on ? glass.activeTile : glass.border,
            ),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: glass.tileStatus
                    .copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
              if (widget.value.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  widget.value,
                  style: glass.labelCaps.copyWith(color: fgSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
