import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/telemetry_reading.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../cage_control_actions.dart';
import '../home_control_providers.dart';

/// 사육장 제어 그리드 — Figma A.4 ④ (타일 180.5×72, 갭 8, radius 12).
///
/// 타일 5개(환기팬·분무·냉각팬·히터팬·LED) 2열 3행, 마지막 홀수 칸은 빈 칸.
/// ON = 기기색 타일(deviceXBg + 아이콘 원 deviceX), OFF = surfaceTint +
/// 아이콘 원 deviceOff. LED는 켜짐+밝기 보고 시 [GlassPalette.deviceLedGauge]가
/// 밝기 비율만큼 좌측을 채운다.
///
/// **사육장 제어의 유일한 진입점**이며, 탭 동작은 전부 기존
/// [cage_control_actions] 경유(히터 2단 안전확인·분무 5초 잠금이 거기 있다).
/// 냉각팬·히터팬은 **미배선**(terra-server 계약 없음, 2026-09-02 기획 B.3) —
/// 탭하면 "준비 중" 안내만 낸다. **절대 toggle 명령을 만들지 말 것.**
class CageControlGrid extends ConsumerWidget {
  const CageControlGrid({super.key});

  static const ventFanKey = Key('cage_control_vent_fan');
  static const mistKey = Key('cage_control_mist');
  static const coolFanKey = Key('cage_control_cool_fan');
  static const heatFanKey = Key('cage_control_heat_fan');
  static const ledKey = Key('cage_control_led');

  static const double _tileHeight = 72;
  static const double _gap = 8;

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

    final fanOn = t?.fan == ActuatorState.on;
    final ledOn = t?.led == ActuatorState.on;

    final tiles = <Widget>[
      // ① 환기팬 — 기존 fan_* 절대 명령 배선.
      _DeviceTile(
        key: ventFanKey,
        name: 'device_vent_fan'.tr(),
        status: _stateLabel(t?.fan),
        icon: Icons.wind_power,
        active: fanOn,
        tileColor: fanOn ? glass.deviceFanBg : glass.surfaceTint,
        iconCircleColor: fanOn ? glass.deviceFan : glass.deviceOff,
        onTap: online ? () => handleFanTap(context, ref, deviceId, t) : null,
      ),
      // ② 분무 — 모멘터리(작동 후 5초 잠금). '켜진 상태'가 없어 잠금 중에만
      // humid 색으로 "지금 작동함"을 말한다.
      _DeviceTile(
        key: mistKey,
        name: 'device_mist'.tr(),
        status: mistLocked
            ? 'home_mist_cooldown_short'.tr()
            : 'home_mist_seconds'.tr(args: ['${mistDuration.seconds}']),
        icon: Icons.water_drop,
        active: mistLocked,
        tileColor: mistLocked ? glass.mistTint : glass.surfaceTint,
        iconCircleColor: mistLocked ? glass.deviceMist : glass.deviceOff,
        onTap: online && !mistLocked
            ? () => openMistSheet(context, ref, deviceId)
            : null,
      ),
      // ③ 냉각팬 — API 없음, 미배선(UI만).
      _DeviceTile(
        key: coolFanKey,
        name: 'device_cool_fan'.tr(),
        status: 'device_status_pending'.tr(),
        icon: Icons.ac_unit,
        active: false,
        tileColor: glass.surfaceTint,
        iconCircleColor: glass.deviceOff,
        onTap: () => _notReady(context),
      ),
      // ④ 히터팬 — API 없음, 미배선. 기존 heater_* 귀속은 미결 Q(B.3) —
      // 여기서 heater 명령을 이어붙이지 말 것(안전확인 플로우 재설계 전).
      _DeviceTile(
        key: heatFanKey,
        name: 'device_heat_fan'.tr(),
        status: 'device_status_pending'.tr(),
        icon: Icons.local_fire_department,
        active: false,
        tileColor: glass.surfaceTint,
        iconCircleColor: glass.deviceOff,
        onTap: () => _notReady(context),
      ),
      // ⑤ LED — `telemetry.led`/`led_brightness`만 믿는다(2026-08-18 회신 §4).
      // 구 펌웨어(unavailable)는 "상태 모름"으로 말하고 켜기/끄기 시트를 연다.
      _DeviceTile(
        key: ledKey,
        name: 'device_led'.tr(),
        status: _ledLabel(t),
        icon: Icons.lightbulb,
        active: ledOn,
        tileColor: ledOn ? glass.deviceLedBg : glass.surfaceTint,
        iconCircleColor: ledOn ? glass.deviceLed : glass.deviceOff,
        gaugeFraction: ledOn && t?.ledBrightness != null
            ? (t!.ledBrightness!.clamp(0, 100)) / 100
            : null,
        gaugeColor: glass.deviceLedGauge,
        onTap: online
            ? () => openLedSheet(context, ref, deviceId,
                // 꺼져 있을 때 보고되는 0을 시드로 넘기면 슬라이더가 1%로
                // 열린다 — 켜져 있을 때의 밝기만 넘긴다.
                currentBrightness: ledOn ? t?.ledBrightness : null)
            : null,
      ),
    ];

    return Column(
      children: [
        for (var row = 0; row * 2 < tiles.length; row++) ...[
          if (row > 0) const SizedBox(height: _gap),
          Row(
            children: [
              Expanded(
                child:
                    SizedBox(height: _tileHeight, child: tiles[row * 2]),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: SizedBox(
                  height: _tileHeight,
                  child: row * 2 + 1 < tiles.length
                      ? tiles[row * 2 + 1]
                      // 마지막 홀수 칸은 빈 칸(Figma A.4 ④).
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('home_device_not_ready'.tr())),
      );
  }

  /// 켜짐 + 밝기 보고(MOSFET)면 `60%`, on/off면 켜짐/꺼짐, 모르면 "상태 모름".
  static String _ledLabel(TelemetryReading? t) {
    if (t == null || t.led == ActuatorState.unavailable) {
      return 'device_state_unknown'.tr();
    }
    if (t.led == ActuatorState.on && t.ledBrightness != null) {
      return 'unit_percent_fmt'.tr(args: ['${t.ledBrightness}']);
    }
    return _stateLabel(t.led);
  }

  static String _stateLabel(ActuatorState? s) {
    switch (s) {
      case ActuatorState.on:
        return 'device_state_on'.tr();
      case ActuatorState.off:
        return 'device_state_off'.tr();
      default:
        return 'device_state_unknown'.tr();
    }
  }
}

/// 제어 타일 한 칸 — 좌 40×40 radius 20 아이콘 원 + 이름 16 SemiBold +
/// 상태 14 Medium(켜짐 textSecondary / 꺼짐 textTertiary), 패딩 16.
class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    super.key,
    required this.name,
    required this.status,
    required this.icon,
    required this.active,
    required this.tileColor,
    required this.iconCircleColor,
    this.gaugeFraction,
    this.gaugeColor,
    this.onTap,
  });

  final String name;
  final String status;
  final IconData icon;
  final bool active;
  final Color tileColor;
  final Color iconCircleColor;

  /// LED 밝기 게이지(0~1). null이면 게이지 없음.
  final double? gaugeFraction;
  final Color? gaugeColor;

  /// null이면 비활성(오프라인 등) — 탭 무반응.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: tileColor),
          if (gaugeFraction != null && gaugeColor != null)
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: gaugeFraction!.clamp(0.0, 1.0),
              child: ColoredBox(color: gaugeColor!),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconCircleColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // 원 안 글리프는 항상 흰색 — 기기색/deviceOff 원 위에서
                      // 켜짐·꺼짐 모두 대비가 나온다(Figma Asset).
                      child: Icon(icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 16 * -0.02,
                              color: glass.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 14 * -0.02,
                              color: active
                                  ? glass.textSecondary
                                  : glass.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
