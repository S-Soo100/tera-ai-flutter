import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/fan_actuator.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/device_command.dart';
import '../../../my_cage/domain/telemetry_reading.dart';
import '../../../my_cage/presentation/management_colors.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../../domain/fan_timer_duration.dart';
import '../../domain/running_timer.dart';
import '../../domain/schedule.dart';
import '../../domain/schedule_device.dart';
import '../cage_control_actions.dart';
import '../control_pending.dart';
import '../home_control_providers.dart';
import '../routine_settings_screen.dart'
    show
        ScheduleRow,
        ScheduleSwitch,
        scheduleRepeatLabel,
        scheduleRows,
        scheduleSingleTitle,
        scheduleStateLabel;
import '../schedule_draft_apply.dart';
import '../schedule_providers.dart';
import 'control_loading_overlay.dart';
import 'led_brightness_row.dart';
import 'running_timer_chip.dart';
import 'schedule_device_badge.dart';
import 'schedule_editor_sheet.dart';

/// 홈 제어 타일 → 기기 제어 시트(Figma 1107:7995 BottomSheet 계열).
///
/// 시트 `#F4F4F4`·안쪽 24. 상단 segment [즉시 작동 | 예약 작동](345×32).
/// 즉시 탭: "전원 · 켜짐/꺼짐" 행(345×48 흰색, 80×32 스위치) + 기기별
/// 선택(환기팬 작동 시간 칩 / 냉각팬 종료 칩+안내 / LED 밝기 행 / 분무
/// "1회 분사 시작"). 예약 탭: 그 기기의 예약 목록 + "새 예약 추가" 또는
/// 인라인 편집기([ScheduleEditorBody]) + "예약 저장".
///
/// **송신 규칙(계획 A1, 2026-09-14 결정 유지):** 칩·슬라이더 선택만으로는
/// 명령을 보내지 않는다. 전원 스위치가 명시적 시작/정지다 — 꺼짐→켜짐이면
/// 고른 값으로 `*_on`, 켜짐→꺼짐이면 `*_off`. 이미 켜진 기기에서 칩을 바꾸면
/// 그 값으로 다시 켠다(타이머 교체). 원본에 별도 시작 버튼이 없어 스위치를
/// 시작으로 삼았다(RESULTS §결정 A1').
///
/// 예약 잠금("예약 일정이 작동 중입니다")은 서버에 진행 중 판정이 없어 넣지
/// 않았다(계획 A8). LED 작동 시간 칩은 펌웨어 미지원으로 뺐다(A7).
Future<void> openDeviceControlSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  ScheduleDevice device, {
  DeviceControlTab initialTab = DeviceControlTab.immediate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // 탭 셸(StatefulShellRoute) 안에서 열리므로 루트 내비게이터에 띄워야
    // 하단 탭바까지 덮는다(Figma BottomSheet는 화면 바닥에서 시작).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Figma 시트 프레임(1107:7996·8469·8134)은 뒤 화면을 어둡게 하지 않고 시트
    // 상단 그림자로만 구분한다(2026-09-18 사용자 결정). 바깥 탭 닫힘은 유지.
    barrierColor: Colors.transparent,
    builder: (_) => DeviceControlSheet(
        deviceId: deviceId, device: device, initialTab: initialTab),
  );
}

enum DeviceControlTab { immediate, scheduled }

class DeviceControlSheet extends ConsumerStatefulWidget {
  const DeviceControlSheet(
      {super.key,
      required this.deviceId,
      required this.device,
      this.initialTab = DeviceControlTab.immediate});

  final String deviceId;
  final ScheduleDevice device;
  final DeviceControlTab initialTab;

  static const surfaceKey = Key('device_sheet_surface');
  static const segmentKey = Key('device_sheet_segment');
  static const immediateTabKey = Key('device_sheet_tab_immediate');
  static const scheduledTabKey = Key('device_sheet_tab_scheduled');
  static const powerRowKey = Key('device_sheet_power_row');
  static const powerSwitchKey = Key('device_sheet_power_switch');
  static const loadingKey = Key('device_sheet_loading');
  static const mistStartKey = Key('device_sheet_mist_start');
  static const addScheduleKey = Key('device_sheet_add_schedule');
  static const saveScheduleKey = Key('device_sheet_save_schedule');
  static const brightnessSliderKey = Key('device_sheet_brightness_slider');

  @override
  ConsumerState<DeviceControlSheet> createState() => _DeviceControlSheetState();
}

/// 예약 탭의 편집 대상 — 새 예약([device]) 또는 기존([single]/[pair]).
class _Editing {
  const _Editing.add()
      : single = null,
        pair = null;
  const _Editing.single(this.single) : pair = null;
  const _Editing.pair(this.pair) : single = null;
  final Schedule? single;
  final SchedulePair? pair;
}

class _DeviceControlSheetState extends ConsumerState<DeviceControlSheet> {
  late DeviceControlTab _tab = widget.initialTab;

  /// 환기팬 작동 시간 선택(null = 계속). 냉각팬은 30/60/120분만.
  FanTimerDuration? _fanChoice;
  bool _fanChoiceSeeded = false;
  double _brightness = 60;
  bool _brightnessSeeded = false;
  _Editing? _editing;
  ScheduleDraft? _draft;
  bool _saving = false;

  /// 명령 왕복 중 잠금 — 스위치·칩 연타로 두 번 보내지 않는다(리뷰 2026-09-16,
  /// 구 FanDurationSheet의 submitted 잠금과 같은 역할).
  bool _sending = false;

  /// 이 사육장의 제어가 기기 확인을 기다리는 중 — 시트 제어 전체를 잠근다
  /// (2026-09-22 사용자 결정, [controlPendingProvider]).
  bool get _busy =>
      _sending || ref.read(controlPendingProvider(widget.deviceId)) != null;

  Future<void> _locked(Future<void> Function() run) async {
    if (_busy) return;
    setState(() => _sending = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  FanActuator? get _actuator => switch (widget.device) {
        ScheduleDevice.fan => FanActuator.ventilation,
        ScheduleDevice.cool => FanActuator.cooling,
        _ => null,
      };

  Color _accent(BuildContext context) =>
      scheduleDeviceColor(context, widget.device) ?? context.glass.textPrimary;

  ActuatorState? _powerState(TelemetryReading? t) => switch (widget.device) {
        ScheduleDevice.fan => t?.fan,
        ScheduleDevice.cool => t?.fan2,
        ScheduleDevice.led => t?.led,
        _ => null,
      };

  /// 환기팬 칩 시드: 진행 중 타이머 → 그 길이, 켜짐(타이머 없음) → 계속,
  /// 꺼짐 → 직전 저장값(기본 30분). 냉각팬은 계속이 없어 30분.
  void _seedFanChoice(bool on, RunningTimer? timer) {
    if (_fanChoiceSeeded) return;
    _fanChoiceSeeded = true;
    final cooling = widget.device == ScheduleDevice.cool;
    if (timer != null) {
      _fanChoice = FanTimerDuration.values
          .where((d) => d.minutes == timer.durationMinutes)
          .firstOrNull;
      if (_fanChoice == null && cooling) _fanChoice = FanTimerDuration.m30;
      return;
    }
    if (on) {
      _fanChoice = cooling ? FanTimerDuration.m30 : null;
      return;
    }
    final saved = ref
        .read(fanChoiceStoreProvider)
        .load(_actuator!.storageKey(widget.deviceId));
    _fanChoice = cooling && (saved == null || saved == FanTimerDuration.m10)
        ? FanTimerDuration.m30
        : saved;
  }

  void _seedBrightness(TelemetryReading? t) {
    if (_brightnessSeeded) return;
    _brightnessSeeded = true;
    final reported = t?.led == ActuatorState.on ? t?.ledBrightness : null;
    final seed = (reported ?? 0) > 0 ? reported! : 60;
    _brightness = ((seed / 10).round() * 10).clamp(20, 100).toDouble();
  }

  /// build에서 watch한 값 — autoDispose provider를 ref.read로만 만지면 시트가
  /// 열려 있는 동안 dispose돼 "로딩"으로 읽힌다(대상 검증이 헛돈다).
  bool _dimmable = false;
  String? _currentDeviceId;
  bool _online = false;

  bool _targetStillValid() {
    if (_currentDeviceId != widget.deviceId || !_online) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('home_fan_target_changed'.tr())));
      return false;
    }
    return true;
  }

  Future<void> _fanPower(bool on) => _locked(() async {
        final actuator = _actuator!;
        if (!_targetStillValid()) return;
        if (!on) {
          await stopFan(context, ref, widget.deviceId, actuator: actuator);
          return;
        }
        final wasOn = actuatorStateOf(
                ref.read(telemetryStreamProvider(widget.deviceId)).valueOrNull,
                widget.device) ==
            ActuatorState.on;
        final choice = _fanChoice;
        // await 뒤에 ref를 쓰지 않도록 저장소를 먼저 잡는다(시트가 닫힐 수 있다).
        final store = ref.read(fanChoiceStoreProvider);
        final key = actuator.storageKey(widget.deviceId);
        await startFan(context, ref, widget.deviceId, choice,
            actuator: actuator, wasOn: wasOn);
        await store.save(key, choice);
      });

  Future<void> _fanChip(FanTimerDuration? d, bool on) async {
    if (_busy) return;
    setState(() => _fanChoice = d);
    // 켜진 채 바꾸면 그 값으로 다시 켠다(타이머 교체). 꺼져 있으면 선택만.
    if (on) await _fanPower(true);
  }

  Future<void> _ledPower(bool on) => _locked(() async {
        if (!_targetStillValid()) return;
        final current = actuatorStateOf(
            ref.read(telemetryStreamProvider(widget.deviceId)).valueOrNull,
            ScheduleDevice.led);
        // 구 펌웨어(상태 미보고)는 기다려도 보고가 오지 않는다 — ACK로만 확인하고
        // 목표 상태를 그리지 않는다("상태 모름" 유지, CLAUDE.md LED 규칙).
        final known = current == ActuatorState.on || current == ActuatorState.off;
        await sendCageCommand(
          context,
          ref,
          widget.deviceId,
          on ? CommandAction.ledOn : CommandAction.ledOff,
          device: ScheduleDevice.led,
          // 켜진 채 밝기만 바꾸면 상태 변화가 없어 ACK로만 확인한다.
          expectOn: !known || (on && current == ActuatorState.on) ? null : on,
          payload: ledCommandPayload(
              on: on, dimmable: _dimmable, brightness: _brightness.round()),
        );
      });

  Future<void> _saveDraft() async {
    final draft = _draft;
    final editing = _editing;
    if (draft == null || editing == null || _saving) return;
    setState(() => _saving = true);
    try {
      await applyScheduleDraft(ref, draft,
          editing: editing.single, editingPair: editing.pair);
      if (!mounted) return;
      setState(() {
        _editing = null;
        _draft = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('routine_action_failed'.tr(args: ['$e']))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('routine_action_failed'.tr(args: ['$e']))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final accent = _accent(context);
    _currentDeviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    _online = ref.watch(moduleOnlineProvider(widget.deviceId));
    _dimmable = ref
            .watch(deviceListProvider)
            .valueOrNull
            ?.where((d) => d.id == widget.deviceId)
            .firstOrNull
            ?.ledDimmable ??
        false;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // 딤이 없어 시트와 뒤 화면은 그림자로만 구분한다. 원본 시트 export에
      // 그림자 여백 20이 붙지만 MCP가 effect 값을 주지 않아, 디자이너가 준
      // 드롭다운 그림자(blur20 #919497 30%)를 재사용한 근사값이다.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: glass.menuShadow, blurRadius: 20)],
        ),
        // 원본 BottomSheet 위 모서리 24(export PNG 실측: y24부터 전폭 채움).
        child: ClipRRect(
          key: DeviceControlSheet.surfaceKey,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: glass.overlay,
            child: SingleChildScrollView(
              // 원본 마지막 요소 아래 52 = 18 + 홈 인디케이터 34.
              padding: EdgeInsets.fromLTRB(24, 24, 24, 18 + bottomInset),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Segment(
                        tab: _tab,
                        onChanged: (t) => setState(() {
                              _tab = t;
                              _editing = null;
                              _draft = null;
                            })),
                    const SizedBox(height: 24),
                    if (_tab == DeviceControlTab.immediate)
                      _immediate(context, accent)
                    else
                      _scheduled(context, accent),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── 즉시 작동 ──────────────────────────────────────────────────────────

  Widget _immediate(BuildContext context, Color accent) {
    final t = ref.watch(telemetryStreamProvider(widget.deviceId)).valueOrNull;
    if (widget.device == ScheduleDevice.mist) return _mist(context, accent);

    final pending = ref.watch(controlPendingProvider(widget.deviceId));
    final busy = _sending || pending != null;
    // 누른 장치는 확인될 때까지 목표 상태로 그린다(로딩 표시와 함께).
    final loading = pending?.device == widget.device;
    final expect = loading ? pending!.expectOn : null;
    final state = expect == null
        ? _powerState(t)
        : (expect ? ActuatorState.on : ActuatorState.off);
    final on = state == ActuatorState.on;
    final actuator = _actuator;
    RunningTimer? timer;
    if (actuator != null) {
      final timers = ref.watch(runningTimersProvider).valueOrNull ?? const [];
      timer = timers
          .where((x) => x.actuatorLabelKey == actuator.labelKey)
          .firstOrNull;
      _seedFanChoice(on, timer);
    } else {
      _seedBrightness(t);
    }
    final stateLabel = switch (state) {
      ActuatorState.on => 'device_state_on'.tr(),
      ActuatorState.off => 'device_state_off'.tr(),
      _ => 'device_state_unknown'.tr(),
    };
    // 구 펌웨어(LED unavailable)는 상태를 모른다 — 모르는 상태를 뒤집는 스위치
    // 대신 켜기/끄기를 따로 내놓는다(CLAUDE.md LED 규칙, 리뷰 2026-09-16).
    final unknown = widget.device == ScheduleDevice.led &&
        (state == null || state == ActuatorState.unavailable);
    final children = <Widget>[
      _PowerRow(
          label: 'home_sheet_power_fmt'.tr(args: [stateLabel]),
          on: on,
          accent: accent,
          enabled: !busy,
          loading: loading,
          unknown: unknown,
          onChanged: (v) => switch (widget.device) {
                ScheduleDevice.led => _ledPower(v),
                _ => _fanPower(v),
              }),
      const SizedBox(height: 24),
    ];
    switch (widget.device) {
      case ScheduleDevice.fan:
        children.add(ScheduleSection(
            label: 'home_fan_duration_label'.tr(),
            gap: 8,
            child: Row(children: [
              for (final (i, d) in FanTimerDuration.values.indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                    child: ScheduleChoiceChip(
                        key: Key('fan_timer_${d.minutes}'),
                        label: d.labelKey.tr(),
                        selected: _fanChoice == d,
                        accent: accent,
                        enabled: !busy,
                        onTap: () => _fanChip(d, on))),
              ],
              const SizedBox(width: 4),
              SizedBox(
                  width: 80,
                  child: ScheduleChoiceChip(
                      key: const Key('fan_steady_on'),
                      label: 'home_fan_steady_on'.tr(),
                      selected: _fanChoice == null,
                      accent: accent,
                      enabled: !busy,
                      onTap: () => _fanChip(null, on))),
            ])));
      case ScheduleDevice.cool:
        children.add(ScheduleSection(
            label: 'home_cooling_end_label'.tr(),
            gap: 8,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text('home_cooling_end_hint'.tr(),
                          style: managementStyle(context,
                              size: 14, color: context.glass.textTertiary))),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final (i, d) in const [
                      FanTimerDuration.m30,
                      FanTimerDuration.h1,
                      FanTimerDuration.h2
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                          child: ScheduleChoiceChip(
                              key: Key('fan_timer_${d.minutes}'),
                              label: 'home_timer_later_fmt'
                                  .tr(args: [d.labelKey.tr()]),
                              selected: _fanChoice == d,
                              accent: accent,
                              enabled: !busy,
                              onTap: () => _fanChip(d, on))),
                    ],
                  ]),
                ])));
      case ScheduleDevice.led:
        if (_dimmable) {
          children.add(ScheduleSection(
              label: 'home_led_brightness'.tr(),
              gap: 8,
              child: LedBrightnessRow(
                  key: const Key('led_brightness_row'),
                  valueKey: const Key('led_brightness_value'),
                  sliderKey: DeviceControlSheet.brightnessSliderKey,
                  value: _brightness,
                  onChanged:
                      busy ? null : (v) => setState(() => _brightness = v),
                  // 켜진 채 손을 떼면 그 밝기로 다시 켠다. 꺼져 있으면 선택만.
                  onChangeEnd: on && !busy ? (_) => _ledPower(true) : null)));
        } else {
          children.removeLast();
        }
      default:
        children.removeLast();
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _mist(BuildContext context, Color accent) {
    final locked =
        ref.watch(mistLockProvider(widget.deviceId)).isLocked(DateTime.now());
    final pending = ref.watch(mistPendingProvider(widget.deviceId)) ||
        ref.watch(controlPendingProvider(widget.deviceId)) != null;
    return _SheetCta(
        key: DeviceControlSheet.mistStartKey,
        label: 'home_mist_start_once'.tr(),
        // 분무 편집기·목록과 같은 #2E408C(humidAccent).
        color: context.glass.humidAccent,
        onPressed: locked || pending
            ? null
            : () {
                if (!_targetStillValid()) return;
                mistWithUndo(context, ref, widget.deviceId);
              });
  }

  // ── 예약 작동 ──────────────────────────────────────────────────────────

  Widget _scheduled(BuildContext context, Color accent) {
    final schedules = ref.watch(schedulesProvider);
    final all = schedules.valueOrNull ?? const <Schedule>[];
    final rows = scheduleRows(all
        .where((s) => ScheduleDevice.of(s.action) == widget.device)
        .toList());
    final editing = _editing ??
        // 목록이 비어 있으면 바로 편집기(Figma 1106:6415/5648/4890/5524).
        (schedules.hasValue && rows.isEmpty ? const _Editing.add() : null);
    if (editing != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ScheduleEditorBody(
            key: ValueKey(
                'sheet-editor-${editing.single?.id ?? editing.pair?.pairId ?? 'new'}'),
            device: editing.single == null && editing.pair == null
                ? widget.device
                : null,
            initial: editing.single,
            initialPair: editing.pair,
            onChanged: (d) => setState(() => _draft = d)),
        const SizedBox(height: 24),
        _SheetCta(
            key: DeviceControlSheet.saveScheduleKey,
            label: 'home_sheet_save_schedule'.tr(),
            color: accent,
            onPressed: _draft == null || _saving
                ? null
                : () {
                    _editing ??= editing;
                    _saveDraft();
                  }),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, row) in rows.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        _row(row),
      ],
      if (rows.isNotEmpty) const SizedBox(height: 24),
      _SheetCta(
          key: DeviceControlSheet.addScheduleKey,
          label: 'home_sheet_add_schedule'.tr(),
          color: accent,
          onPressed: () => setState(() {
                _editing = const _Editing.add();
                _draft = null;
              })),
    ]);
  }

  Widget _row(Object row) {
    if (row case final SchedulePair p) {
      final on = p.on;
      return ScheduleRow(
        key: Key('schedule_pair_${p.pairId}'),
        device: widget.device,
        title: '${on.hhmm}~${p.off.hhmm}',
        parts: [
          scheduleRepeatLabel(on.kind, on.daysOfWeek),
          scheduleStateLabel(p.enabled),
          if (p.isSkewed) 'routine_pair_skewed'.tr(),
        ],
        enabled: p.enabled,
        toggleKey: Key('schedule_pair_toggle_${p.pairId}'),
        checkKey: Key('schedule_pair_check_${p.pairId}'),
        deleteMode: false,
        selected: false,
        onToggle: (v) => _guard(
            () => ref.read(schedulesProvider.notifier).setPairEnabled(p, v)),
        onTap: () => setState(() {
          _editing = _Editing.pair(p);
          _draft = null;
        }),
      );
    }
    final s = row as Schedule;
    return ScheduleRow(
      key: Key('schedule_${s.id}'),
      device: widget.device,
      title: scheduleSingleTitle(s, widget.device),
      parts: [
        scheduleRepeatLabel(s.kind, s.daysOfWeek),
        scheduleStateLabel(s.enabled),
      ],
      enabled: s.enabled,
      toggleKey: Key('schedule_toggle_${s.id}'),
      checkKey: Key('schedule_check_${s.id}'),
      deleteMode: false,
      selected: false,
      onToggle: (v) =>
          _guard(() => ref.read(schedulesProvider.notifier).setEnabled(s, v)),
      onTap: () => setState(() {
        _editing = _Editing.single(s);
        _draft = null;
      }),
    );
  }
}

/// Figma Toggle_L/R — 345×32 트랙 #E3E3E3 r18, 안쪽 2, 선택 칸 흰색 r14
/// 14/700 #3C3C3C, 비선택 14/600 #626262.
class _Segment extends StatelessWidget {
  const _Segment({required this.tab, required this.onChanged});
  final DeviceControlTab tab;
  final ValueChanged<DeviceControlTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget half(DeviceControlTab t, Key key, String label) {
      final selected = tab == t;
      return Expanded(
          child: Semantics(
              selected: selected,
              button: true,
              child: GestureDetector(
                  key: key,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(t),
                  child: Container(
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: selected
                              ? glass.surfaceHeader
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(label,
                          style: managementStyle(context,
                              size: 14,
                              weight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              color: selected
                                  ? glass.textSecondary
                                  : glass.bodySecondary))))));
    }

    return Container(
        key: DeviceControlSheet.segmentKey,
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            color: glass.border, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          half(DeviceControlTab.immediate, DeviceControlSheet.immediateTabKey,
              'home_sheet_tab_immediate'.tr()),
          half(DeviceControlTab.scheduled, DeviceControlSheet.scheduledTabKey,
              'home_sheet_tab_scheduled'.tr()),
        ]));
  }
}

/// "전원 · 켜짐" 행 — 345×48 흰색 r16, 글자 18/600 왼쪽 12, 스위치 오른쪽 8.
class _PowerRow extends StatelessWidget {
  const _PowerRow(
      {required this.label,
      required this.on,
      required this.accent,
      required this.onChanged,
      this.enabled = true,
      this.loading = false,
      this.unknown = false});
  final String label;
  final bool on;
  final Color accent;
  final ValueChanged<bool> onChanged;

  /// 명령 왕복 중 false — 스위치 탭을 무시한다.
  final bool enabled;

  /// 기기 확인 대기 중 — 행 위에 shimmer를 흘린다.
  final bool loading;

  /// 상태 모름(구 펌웨어) — 스위치 대신 켜기/끄기 버튼 둘.
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final row = Container(
        key: DeviceControlSheet.powerRowKey,
        height: 48,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
            color: glass.surfaceHeader,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: managementStyle(context,
                      size: 18,
                      weight: FontWeight.w600,
                      color: glass.textSecondary))),
          if (unknown) ...[
            _MiniButton(
                key: const Key('led_on'),
                label: 'home_led_turn_on'.tr(),
                color: accent,
                onPressed: enabled ? () => onChanged(true) : null),
            const SizedBox(width: 4),
            _MiniButton(
                key: const Key('led_off'),
                label: 'home_led_turn_off'.tr(),
                color: glass.deviceOff,
                onPressed: enabled ? () => onChanged(false) : null),
          ] else
            ScheduleSwitch(
                key: DeviceControlSheet.powerSwitchKey,
                value: on,
                color: accent,
                onChanged: enabled ? onChanged : (_) {}),
        ]));
    if (!loading) return row;
    return Stack(children: [
      row,
      Positioned.fill(
          child: ControlLoadingOverlay(
              key: DeviceControlSheet.loadingKey,
              borderRadius: BorderRadius.circular(16))),
    ]);
  }
}

/// 시트 CTA — 345×44 r12, 16/600/28 #FAFAFA, 비활성 #E3E3E3.
class _SheetCta extends StatelessWidget {
  const _SheetCta(
      {super.key,
      required this.label,
      required this.color,
      required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 44,
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: context.glass.border,
              foregroundColor: ManagementColors.buttonForeground(context),
              disabledForegroundColor:
                  ManagementColors.buttonForeground(context),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: managementStyle(context, weight: FontWeight.w600)
                  .copyWith(height: 28 / 16)),
          child: Text(label)));
}

/// 상태 모름 LED의 켜기/끄기 — 스위치 자리(32 높이)에 맞춘 작은 버튼.
class _MiniButton extends StatelessWidget {
  const _MiniButton(
      {super.key,
      required this.label,
      required this.color,
      required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 32,
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: context.glass.border,
              foregroundColor: ManagementColors.buttonForeground(context),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  managementStyle(context, size: 14, weight: FontWeight.w600)),
          child: Text(label)));
}
