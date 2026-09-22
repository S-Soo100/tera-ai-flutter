import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/telemetry_reading.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/domain/fan_actuator.dart';
import '../cage_control_actions.dart';
import '../control_pending.dart';
import '../../domain/running_timer.dart';
import '../../domain/schedule_device.dart';
import '../home_control_providers.dart';
import 'control_loading_overlay.dart';
import 'device_control_sheet.dart';
import 'running_timer_chip.dart';

/// 사육장 제어 그리드 — Figma A.4 ④ (타일 180.5×72, 갭 8, radius 12).
///
/// 타일 4개(환기팬·분무·냉각팬·LED) 2열 2행 + **히터팬은 조건부**: 평소엔
/// 숨기고(사용자 지시 2026-09-04, "버튼 5개가 애매함"), **히터가 켜져 있거나
/// 안전잠금 상태일 때만** 5번째 타일로 나타난다(리뷰 2026-09-04) — 예약·웹
/// 콘솔·펌웨어로 켜진 히터를 앱에서 끌 수(잠금을 풀 수) 있는 유일한
/// 진입점이라, 이마저 없으면 과열=개체 폐사 경로가 막힌다. 미관 요구(평소
/// 4타일)와 안전(켜진 히터는 항상 끌 수 있음)을 함께 만족한다.
/// 라이트는 ON/OFF 모두 Figma Fill/Button 타일이고 아이콘 원만 기기색/deviceOff로
/// 상태를 구분한다. 다크는 기기색 배경을 유지한다. LED 밝기 보고 시
/// [GlassPalette.deviceLedGauge]가 밝기 비율만큼 좌측을 채운다.
///
/// **사육장 제어의 유일한 진입점**이며, 탭은 기기 제어 시트
/// ([openDeviceControlSheet], Figma 1107:7995 — 즉시/예약 segment)를 연다.
/// 명령 송신은 전부 [cage_control_actions] 경유(히터 2단 안전확인·분무 5초
/// 잠금이 거기 있다). 냉각팬은 fan2 계약을 사용하며 미보고이면 비활성화한다.
///
/// 타이머 카운트다운은 타일 부제에 쓴다 — "켜짐 · 30m 56s 뒤 꺼짐"(2026-09-16
/// 디자이너 메모 "타이머·예약 사용 시 종료 카운트다운 표시"). 홈 상단 칩은
/// Figma에 없어 내렸다(계획 A4).
class CageControlGrid extends ConsumerWidget {
  const CageControlGrid({super.key});

  static const ventFanKey = Key('cage_control_vent_fan');
  static const mistKey = Key('cage_control_mist');
  static const coolFanKey = Key('cage_control_cool_fan');
  static const heatFanKey = Key('cage_control_heat_fan');
  static const ledKey = Key('cage_control_led');
  static const loadingKey = Key('cage_control_loading');

  static const double _tileHeight = 72;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    // 기기 확인 대기 중이면 모든 타일을 잠그고(2026-09-22 사용자 결정), 누른
    // 타일은 목표 상태 + 로딩으로 그린다 — 시트를 닫아도 여기서 이어 보인다.
    final pending = ref.watch(controlPendingProvider(deviceId));
    final online = ref.watch(moduleOnlineProvider(deviceId)) && pending == null;
    bool loading(ScheduleDevice d) => pending?.device == d;
    ActuatorState? shown(ScheduleDevice d) {
      final expect = loading(d) ? pending!.expectOn : null;
      if (expect == null) return actuatorStateOf(t, d);
      return expect ? ActuatorState.on : ActuatorState.off;
    }

    final lock = ref.watch(mistLockProvider(deviceId));
    final glass = context.glass;
    final mistLocked = lock.isLocked(DateTime.now());
    // 분사 중(릴레이 ON 텔레메트리) 또는 방금 눌러 잠금 중이면 "켜짐" —
    // 텔레메트리는 3초 주기라 3초 펄스를 놓칠 수 있어 잠금을 함께 본다.
    final mistOn = t?.relay == ActuatorState.on || mistLocked;

    final fanOn = shown(ScheduleDevice.fan) == ActuatorState.on;
    final coolOn = shown(ScheduleDevice.cool) == ActuatorState.on;
    final coolAvailable = t != null && t.fan2 != ActuatorState.unavailable;
    final ledOn = shown(ScheduleDevice.led) == ActuatorState.on;
    // 히터 타일 노출 조건 — 켜짐 또는 안전잠금(둘 다 "꺼야/풀어야 할 상태").
    final heaterVisible =
        t?.heaterState == ActuatorState.on || (t?.heaterLocked ?? false);
    // 타이머 목록을 먼저 보고, 있을 때만 1초 tick을 구독한다(칩과 같은 이유).
    final timers = ref.watch(runningTimersProvider).valueOrNull ?? const [];
    final now = timers.isEmpty
        ? DateTime.now()
        : ref.watch(secondTickProvider).valueOrNull ?? DateTime.now();
    RunningTimer? timerOf(FanActuator a) => timers
        .where((x) => x.actuatorLabelKey == a.labelKey && x.isActive(now))
        .firstOrNull;
    String fanStatus(ActuatorState? state, FanActuator a) {
      final timer = state == ActuatorState.on ? timerOf(a) : null;
      if (timer == null) return _stateLabel(state);
      return 'home_tile_on_with_fmt'.tr(args: [
        'home_tile_off_in_fmt'
            .tr(args: [formatCountdownShort(timer.remaining(now))])
      ]);
    }

    void open(ScheduleDevice device) =>
        openDeviceControlSheet(context, ref, deviceId, device);

    final tiles = <Widget>[
      // ① 환기팬 — 탭=제어 시트(즉시 작동: 전원 스위치 + 작동 시간 칩 /
      // 예약 작동). 글리프는 Figma 원본 mode_fan_2(글리프만 20 — 원 40 안 실측
      // 20). 부제는 타이머가 돌면 카운트다운.
      _DeviceTile(
        key: ventFanKey,
        name: 'device_vent_fan'.tr(),
        status: fanStatus(shown(ScheduleDevice.fan), FanActuator.ventilation),
        glyph: FigmaIcon.metric(fanOn ? FigmaIcons.fanOn : FigmaIcons.fanOff,
            size: 40),
        active: fanOn,
        loading: loading(ScheduleDevice.fan),
        tileColor: fanOn ? glass.deviceFanBg : glass.surfaceTint,
        iconCircleColor: fanOn ? glass.deviceFan : glass.deviceOff,
        onTap: online ? () => open(ScheduleDevice.fan) : null,
      ),
      // ② 분무 — 탭=제어 시트("1회 분사 시작" + 실행 취소 2초, 계획 A5 —
      // 2026-09-07의 타일 즉시 분사는 시트 진입으로 바뀜). 모멘터리라
      // 분사(릴레이 ON)+잠금 5초 동안만 "작동 중"으로 말한다.
      _DeviceTile(
        key: mistKey,
        name: 'device_mist'.tr(),
        status: mistOn ? 'device_state_running'.tr() : 'device_state_off'.tr(),
        // 꺼짐=format_color_reset(사선 물방울, 원 40 프레임 export라 40),
        // 켜짐=humidity_high(물방울, 글리프만 17×20 → 20) — 2026-09-08
        // 사용자 지시.
        glyph: FigmaIcon.metric(mistOn ? FigmaIcons.mistOn : FigmaIcons.mistOff,
            size: 40),
        active: mistOn,
        loading: loading(ScheduleDevice.mist),
        tileColor: mistOn ? glass.deviceMistBg : glass.surfaceTint,
        iconCircleColor: mistOn ? glass.deviceMist : glass.deviceOff,
        onTap: online ? () => open(ScheduleDevice.mist) : null,
      ),
      // ③ 냉각팬 — 실제 fan2 상태, 선택/타이머는 환기팬과 분리.
      _DeviceTile(
        key: coolFanKey,
        name: 'device_cool_fan'.tr(),
        status: coolAvailable
            ? fanStatus(shown(ScheduleDevice.cool), FanActuator.cooling)
            : 'home_value_none'.tr(),
        glyph: FigmaIcon.metric(coolOn ? FigmaIcons.coolOn : FigmaIcons.coolOff,
            size: 40),
        active: coolOn,
        loading: loading(ScheduleDevice.cool),
        tileColor: coolOn ? glass.deviceCoolBg : glass.surfaceTint,
        iconCircleColor: coolOn ? glass.deviceCool : glass.deviceOff,
        onTap: online && coolAvailable ? () => open(ScheduleDevice.cool) : null,
      ),
      // ④ LED — `telemetry.led`/`led_brightness`만 믿는다(2026-08-18 회신 §4).
      // 구 펌웨어(unavailable)는 "상태 모름"으로 말하고 켜기/끄기 시트를 연다.
      _DeviceTile(
        key: ledKey,
        name: 'device_led'.tr(),
        status: loading(ScheduleDevice.led) && pending!.expectOn != null
            ? _stateLabel(shown(ScheduleDevice.led))
            : _ledLabel(t),
        glyph: FigmaIcon.metric(ledOn ? FigmaIcons.ledOn : FigmaIcons.ledOff,
            size: 40),
        active: ledOn,
        loading: loading(ScheduleDevice.led),
        tileColor: ledOn ? glass.deviceLedBg : glass.surfaceTint,
        iconCircleColor: ledOn ? glass.deviceLed : glass.deviceOff,
        gaugeFraction: ledOn && t?.ledBrightness != null
            ? (t!.ledBrightness!.clamp(0, 100)) / 100
            : null,
        gaugeColor: glass.deviceLedGauge,
        onTap: online ? () => open(ScheduleDevice.led) : null,
      ),
      // ⑤ 히터팬 — 켜짐/잠금일 때만(클래스 doc). 끄기·잠금 해제 진입점.
      if (heaterVisible)
        _heaterTile(context, ref, deviceId, t, online,
            loading: loading(ScheduleDevice.heater),
            shownState: shown(ScheduleDevice.heater)),
    ];

    return Column(
      children: [
        for (var row = 0; row * 2 < tiles.length; row++) ...[
          if (row > 0) const SizedBox(height: _gap),
          Row(
            children: [
              Expanded(
                child: SizedBox(height: _tileHeight, child: tiles[row * 2]),
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

  /// 히터팬 타일 — **켜짐/잠금일 때만 노출**(클래스 doc, 리뷰 2026-09-04).
  ///
  /// 기존 heater_* 절대 명령 배선(리뷰 2026-09-03 최고 심각 수정). 2단
  /// 안전확인·잠금 다이얼로그는 [handleHeaterTap](cage_control_actions) 안에
  /// 있다. 미결 Q(전용 '히터팬' API)가 확정되면 명령만 갈아끼운다.
  Widget _heaterTile(BuildContext context, WidgetRef ref, String deviceId,
      TelemetryReading? t, bool online,
      {required bool loading, required ActuatorState? shownState}) {
    final glass = context.glass;
    final heaterOn = shownState == ActuatorState.on;
    return _DeviceTile(
      key: heatFanKey,
      name: 'device_heat_fan'.tr(),
      status: _stateLabel(shownState),
      // 조건부 타일이라 Figma에 원본 없음 — Material 유지.
      glyph:
          Icon(Icons.local_fire_department, size: 20, color: glass.deviceGlyph),
      active: heaterOn,
      loading: loading,
      tileColor: heaterOn ? glass.deviceHeatBg : glass.surfaceTint,
      iconCircleColor: heaterOn ? glass.deviceHeat : glass.deviceOff,
      onTap: online ? () => handleHeaterTap(context, ref, deviceId, t) : null,
    );
  }

  /// 켜짐 + 밝기 보고(MOSFET)면 `60%`, on/off면 켜짐/꺼짐, 모르면 "상태 모름".
  static String _ledLabel(TelemetryReading? t) {
    if (t == null || t.led == ActuatorState.unavailable) {
      return 'device_state_unknown'.tr();
    }
    if (t.led == ActuatorState.on && t.ledBrightness != null) {
      return 'redesign_led_on_brightness'.tr(args: ['${t.ledBrightness}']);
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
    required this.glyph,
    required this.active,
    this.loading = false,
    required this.tileColor,
    required this.iconCircleColor,
    this.gaugeFraction,
    this.gaugeColor,
    this.onTap,
  });

  final String name;
  final String status;

  /// 원 안 글리프 — Figma 원본 SVG([FigmaIcon.tinted]) 또는 Material 근사.
  /// 색은 호출부가 `deviceGlyph`로 칠해 넘긴다.
  final Widget glyph;
  final bool active;

  /// 기기 확인 대기 중 — 타일 위에 shimmer를 흘린다.
  final bool loading;
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
                        color: glyph is FigmaIcon &&
                                (glyph as FigmaIcon).color == null
                            ? Colors.transparent
                            : iconCircleColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(child: glyph),
                    ),
                    // Figma 668:872 실측 8 (아이콘끝 247 → 텍스트 255).
                    const SizedBox(width: 8),
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
                          // Figma 668:876 실측 4 (이름끝 2732 → 상태 2736).
                          const SizedBox(height: 4),
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
          if (loading)
            ControlLoadingOverlay(
                key: CageControlGrid.loadingKey,
                borderRadius: BorderRadius.circular(12)),
        ],
      ),
    );
  }
}
