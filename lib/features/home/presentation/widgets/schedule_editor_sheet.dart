import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../my_cage/presentation/management_colors.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../../domain/mist_duration.dart';
import '../../domain/schedule.dart';
import '../../domain/schedule_device.dart';
import 'led_brightness_row.dart';
import 'schedule_device_badge.dart';

/// 편집기가 돌려주는 결과 — 저장([ScheduleDraft]) 또는 하단 "예약 삭제"
/// ([ScheduleDeleteRequested]). 삭제 확인은 목록 화면이 맡는다.
sealed class ScheduleEditorResult {
  const ScheduleEditorResult();
}

/// 편집기가 돌려주는 값. 화면이 그대로 notifier에 넘긴다.
///
/// [offAction]이 있으면 **구간 예약**이다 — 화면이 `addSpan`/`updateSpanTiming`
/// 으로 분기해 같은 `pair_id`의 on/off 2건을 만들거나 고친다.
class ScheduleDraft extends ScheduleEditorResult {
  final ScheduleAction action;

  /// 구간일 때만. [action]이 켜기, 이게 끄기.
  final ScheduleAction? offAction;

  final ScheduleKind kind;
  final int hour;
  final int minute;

  /// 구간일 때만 — 끄는 시각.
  final int? endHour;
  final int? endMinute;

  final List<int> daysOfWeek;
  final Map<String, dynamic>? payload;
  final ScheduleGuard? guard;

  /// 수정에서 기존 가드를 껐다 — PATCH에 명시적 `guard: null`을 실어야 한다.
  /// Figma 편집기(1106:7234)에는 가드 UI가 없어 항상 false — 이미 걸린 가드는
  /// 건드리지 않는다(삭제·재활성화 금지).
  final bool clearGuard;

  const ScheduleDraft({
    required this.action,
    required this.kind,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    required this.payload,
    this.offAction,
    this.endHour,
    this.endMinute,
    this.guard,
    this.clearGuard = false,
  });

  bool get isSpan => offAction != null;
}

class ScheduleDeleteRequested extends ScheduleEditorResult {
  const ScheduleDeleteRequested();
}

/// 예약 추가·수정 전체 화면(Figma 1106:7234 환기팬 / 1107:8758 LED /
/// 1107:9131 냉각팬 / 1107:9236 분무, 수정은 1107:9325~9578).
///
/// 새 예약은 [device]로 종류가 정해지고, 수정([initial] 시점 / [initialPair]
/// 구간)은 동작을 못 바꾼다 — 서버가 `action` 수정을 안 받는다.
///
/// 폼 본문은 [ScheduleEditorBody]다 — 홈 제어 시트의 예약 탭(Figma
/// 1106:5524/5648/4890/6415)이 같은 본문을 시트 안에 인라인으로 쓴다.
Future<ScheduleEditorResult?> showScheduleEditor(
  BuildContext context, {
  ScheduleDevice? device,
  Schedule? initial,
  SchedulePair? initialPair,
}) {
  assert(initial == null || initialPair == null);
  assert(device != null || initial != null || initialPair != null);
  return Navigator.of(context).push<ScheduleEditorResult>(MaterialPageRoute(
      builder: (_) => ScheduleEditorScreen(
          device: device, initial: initial, initialPair: initialPair)));
}

class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen(
      {super.key, this.device, this.initial, this.initialPair});

  final ScheduleDevice? device;
  final Schedule? initial;
  final SchedulePair? initialPair;

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  ScheduleDraft? _draft;

  bool get _isEdit => widget.initial != null || widget.initialPair != null;

  ScheduleDevice? get _device =>
      widget.device ??
      ScheduleDevice.of(
          widget.initial?.action ?? widget.initialPair!.on.action);

  String _title() {
    final name = _device?.nameKey.tr() ??
        (widget.initial?.action ?? widget.initialPair!.on.action)
            .displayKey
            .tr();
    return 'routine_device_title_fmt'.tr(args: [name]);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
        backgroundColor: glass.surfaceTint,
        body: Stack(children: [
          SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ManagementTopBar(
                        title: _title(), onBack: () => Navigator.pop(context))),
                Expanded(
                    child: SingleChildScrollView(
                        // 원본 x24, 첫 라벨 y117.5(헤더 61.5+44+12).
                        padding: EdgeInsets.fromLTRB(24, 12, 24,
                            bottom + (_isEdit ? 122 : 66) + 56 + 24),
                        child: ScheduleEditorBody(
                            device: widget.device,
                            initial: widget.initial,
                            initialPair: widget.initialPair,
                            onChanged: (d) => setState(() => _draft = d)))),
              ])),
          Positioned(
              left: 12,
              right: 12,
              bottom: bottom + (_isEdit ? 10 : 66),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ManagementButton(
                    key: const Key('routine_save'),
                    label: 'routine_editor_save'.tr(),
                    onPressed: _draft == null
                        ? null
                        : () => Navigator.pop(context, _draft)),
                if (_isEdit)
                  SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: TextButton(
                          key: const Key('routine_delete'),
                          onPressed: () => Navigator.pop(
                              context, const ScheduleDeleteRequested()),
                          style: TextButton.styleFrom(
                              foregroundColor: glass.navSelected,
                              // 원본 1107:9325 글자 실측 61×14 → 18/600.
                              textStyle: managementStyle(context,
                                  size: 18, weight: FontWeight.w600)),
                          child: Text('routine_delete_title'.tr()))),
              ])),
        ]));
  }
}

/// 12시간제 한 칸 — 오전/오후 + 1~12시 + 분. 서버 24시간제와 여기서만 오간다.
class ScheduleClock {
  ScheduleClock(int hour24, this.minute)
      : pm = hour24 >= 12,
        hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

  bool pm;
  int hour12;
  int minute;

  /// 분 화살표 한 칸 — 디자이너 메모 "시각 설정 분: 10분 단위 ±"(2026-09-16).
  static const minuteStep = 10;

  int get hour24 => (hour12 % 12) + (pm ? 12 : 0);

  /// 시는 1~12를 돈다. 오전/오후는 버튼이 따로 있어 시가 넘어가도 안 바뀐다.
  void stepHour(int delta) =>
      hour12 = ((hour12 - 1 + delta) % 12 + 12) % 12 + 1;

  /// 분은 [minuteStep] 단위로 돈다. 눈금 밖의 기존 값은 화살표 한 번에 가까운
  /// 눈금으로 들어간다.
  void stepMinute(int delta) {
    const st = minuteStep;
    final base =
        delta > 0 ? (minute ~/ st) * st : ((minute + st - 1) ~/ st) * st;
    minute = ((base + delta * st) % 60 + 60) % 60;
  }
}

/// 예약 편집 폼 본문(시작·종료·밝기·종료 칩·반복). 값이 바뀔 때마다
/// [onChanged]로 현재 초안을 알린다 — 저장 불가 상태(냉각팬 종료 미선택)면
/// null. 첫 프레임 뒤에도 한 번 알린다. 저장 버튼은 호출자가 그린다(전체
/// 화면은 플로팅, 제어 시트는 폼 아래 인라인).
class ScheduleEditorBody extends StatefulWidget {
  const ScheduleEditorBody(
      {super.key,
      this.device,
      this.initial,
      this.initialPair,
      required this.onChanged});

  final ScheduleDevice? device;
  final Schedule? initial;
  final SchedulePair? initialPair;
  final ValueChanged<ScheduleDraft?> onChanged;

  @override
  State<ScheduleEditorBody> createState() => _ScheduleEditorBodyState();
}

class _ScheduleEditorBodyState extends State<ScheduleEditorBody> {
  late final ScheduleDevice? _device;
  late final ScheduleEditorKind _kind;
  late final ScheduleClock _start;
  late final ScheduleClock _end;
  int? _coolMinutes;
  late final Set<int> _days;

  /// 분무 예약의 분사 시간. 새 예약은 5초. 옛 1/2/3초 예약을 열면 null(칩
  /// 미선택)이고 저장값을 그대로 둔다 — 고르기 전엔 원본에 없는 값을 만들어
  /// 넣지 않는다(2026-09-23).
  MistDuration? _mistChoice;

  bool get _isMistPoint =>
      _kind == ScheduleEditorKind.point && _action.requiresDuration;

  /// LED 구간 예약의 밝기(%) — Figma 1107:8758 밝기 행, 기본 50. 켜기 행
  /// `payload.brightness`로 싣는다(2026-09-16 계약 확인 전 미리 구현).
  double _brightness = 50;

  ScheduleAction get _action =>
      widget.initial?.action ??
      widget.initialPair?.on.action ??
      widget.device!.onAction;

  @override
  void initState() {
    super.initState();
    final pair = widget.initialPair;
    final base = widget.initial ?? pair?.on;
    _device = widget.device ?? ScheduleDevice.of(_action);
    // 냉각팬 duration 예약(fan2_on + payload.duration_ms 한 건)은 시점이 아니라
    // duration 편집기로 연다(2026-09-16 미리 구현 — pair 대신 payload).
    final singleDurationMs =
        (widget.initial?.payload?['duration_ms'] as num?)?.toInt();
    final singleCool = widget.initial?.action == ScheduleAction.fan2On &&
        singleDurationMs != null &&
        singleDurationMs > 0;
    _kind = pair != null
        ? (_device?.kind == ScheduleEditorKind.duration
            ? ScheduleEditorKind.duration
            : ScheduleEditorKind.span)
        : widget.initial != null
            ? (singleCool
                ? ScheduleEditorKind.duration
                : ScheduleEditorKind.point)
            : widget.device!.kind;
    final savedBrightness =
        ((pair?.on ?? widget.initial)?.payload?['brightness'] as num?)
            ?.toDouble();
    if (savedBrightness != null) {
      _brightness =
          ((savedBrightness / 10).round() * 10).clamp(20, 100).toDouble();
    }
    // Figma 예시(오후 12:00 → 오후 2:00)를 새 예약의 출발값으로 쓴다.
    _start = ScheduleClock(base?.hour ?? 12, base?.minute ?? 0);
    _end = ScheduleClock(pair?.off.hour ?? 14, pair?.off.minute ?? 0);
    if (_kind == ScheduleEditorKind.duration) {
      if (singleCool) {
        final minutes = singleDurationMs ~/ 60000;
        _coolMinutes =
            ScheduleDevice.coolDurations.contains(minutes) ? minutes : null;
      } else if (pair == null) {
        _coolMinutes = ScheduleDevice.coolDurations.first;
      } else {
        // 기존 구간 길이가 30/60/120분이면 그 칩, 아니면 미선택(고르기 전엔
        // 저장 불가) — 원본에 없는 값을 만들어 넣지 않는다.
        final diff = ((pair.off.hour * 60 + pair.off.minute) -
                (pair.on.hour * 60 + pair.on.minute)) %
            (24 * 60);
        _coolMinutes =
            ScheduleDevice.coolDurations.contains(diff) ? diff : null;
      }
    }
    if (_isMistPoint) {
      final saved = (widget.initial?.payload?['duration_ms'] as num?)?.toInt();
      final kept = MistDuration.tryFromMilliseconds(saved);
      _mistChoice = widget.initial == null
          ? MistDuration.defaultValue
          // 예약에 못 쓰는 값(6·9초)은 고른 것으로 두지 않는다 — 저장이 막힌다.
          : (kept != null && kept.schedulable ? kept : null);
    }
    _days = {...?base?.daysOfWeek};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_draft());
    });
  }

  bool get _valid =>
      _kind != ScheduleEditorKind.duration || _coolMinutes != null;

  void _update(VoidCallback change) {
    setState(change);
    widget.onChanged(_draft());
  }

  Color _accent(BuildContext context) =>
      scheduleDeviceColor(context, _device) ?? context.glass.textPrimary;

  ScheduleDraft? _draft() {
    if (!_valid) return null;
    final kind = _days.isEmpty ? ScheduleKind.daily : ScheduleKind.weekly;
    final days = _days.toList()..sort();
    final pair = widget.initialPair;
    switch (_kind) {
      case ScheduleEditorKind.point:
        final action = _action;
        return ScheduleDraft(
          action: action,
          kind: kind,
          hour: _start.hour24,
          minute: _start.minute,
          daysOfWeek: days,
          // 분무는 고른 분사 시간. 칩을 안 고른 옛 예약(1/2/3초)은 저장된
          // 값을 그대로 둔다.
          payload: _mistChoice?.payload ?? widget.initial?.payload,
        );
      case ScheduleEditorKind.span:
      case ScheduleEditorKind.duration:
        if (_kind == ScheduleEditorKind.duration && pair == null) {
          // 새 냉각팬 예약·duration 단건 수정: fan2_on 한 건 + duration_ms
          // (2026-09-16 사용자 결정 — 서버 duration 지원은 요청 문서로 확인).
          return ScheduleDraft(
            action: widget.initial?.action ?? _device!.onAction,
            kind: kind,
            hour: _start.hour24,
            minute: _start.minute,
            daysOfWeek: days,
            payload: {'duration_ms': _coolMinutes! * 60000},
          );
        }
        var endHour = _end.hour24;
        var endMinute = _end.minute;
        if (_kind == ScheduleEditorKind.duration) {
          final total =
              (_start.hour24 * 60 + _start.minute + _coolMinutes!) % (24 * 60);
          endHour = total ~/ 60;
          endMinute = total % 60;
        }
        return ScheduleDraft(
          action: pair?.on.action ?? _device!.onAction,
          offAction: pair?.off.action ?? _device!.offAction,
          kind: kind,
          hour: _start.hour24,
          minute: _start.minute,
          endHour: endHour,
          endMinute: endMinute,
          daysOfWeek: days,
          payload: _device == ScheduleDevice.led
              ? {'brightness': _brightness.round()}
              : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ScheduleSection(
          label: 'routine_start'.tr(),
          child: ScheduleTimeRow(
              prefix: 'routine_start',
              clock: _start,
              accent: accent,
              onChanged: () => _update(() {}))),
      if (_isMistPoint) ...[
        const SizedBox(height: 24),
        // 냉각팬 종료 칩과 같은 행(높이 44, 간격 6, y310) — 두 편집기가 같은
        // 자리에 칩과 반복을 둔다. 칩은 3개라 셋으로 나눈다.
        ScheduleSection(
            label: 'home_mist_duration_label'.tr(),
            gap: 8,
            child: Row(children: [
              for (final (i, d) in MistDuration.values.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                    child: ScheduleChoiceChip(
                        key: Key('routine_mist_${d.seconds}'),
                        label: 'home_mist_seconds'.tr(args: ['${d.seconds}']),
                        selected: _mistChoice == d,
                        accent: accent,
                        // 예약은 서버가 한 번에 실행해 앱이 이어 보낼 수 없다 —
                        // 서버가 6·9초를 받기 전까지 3초만(2026-09-25).
                        enabled: d.schedulable,
                        onTap: () => _update(() => _mistChoice = d))),
              ],
            ])),
        if (MistDuration.values.any((d) => !d.schedulable)) ...[
          const SizedBox(height: 8),
          Text('home_mist_schedule_only_three'.tr(),
              key: const Key('routine_mist_only_three'),
              style: managementStyle(context,
                  size: 14, color: context.glass.textTertiary)),
        ],
      ],
      if (_kind == ScheduleEditorKind.span) ...[
        const SizedBox(height: 24),
        ScheduleSection(
            label: 'routine_end'.tr(),
            child: ScheduleTimeRow(
                prefix: 'routine_end',
                clock: _end,
                accent: accent,
                onChanged: () => _update(() {}))),
      ],
      if (_kind == ScheduleEditorKind.span &&
          _device == ScheduleDevice.led) ...[
        const SizedBox(height: 24),
        // Figma 1107:8758 — 밝기 y447.5, 행 y474.5.
        ScheduleSection(
            label: 'home_led_brightness'.tr(),
            gap: 8,
            child: LedBrightnessRow(
                key: const Key('routine_brightness_row'),
                valueKey: const Key('routine_brightness_value'),
                sliderKey: const Key('routine_brightness_slider'),
                value: _brightness,
                onChanged: (v) => _update(() => _brightness = v))),
      ],
      if (_kind == ScheduleEditorKind.duration) ...[
        const SizedBox(height: 24),
        ScheduleSection(
            label: 'routine_end'.tr(),
            gap: 8,
            child: Row(children: [
              for (final (i, m) in ScheduleDevice.coolDurations.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                    child: ScheduleChoiceChip(
                        key: Key('routine_after_$m'),
                        label: 'home_timer_later_fmt'.tr(args: [
                          (m < 60
                                  ? 'home_timer_${m}m'
                                  : 'home_timer_${m ~/ 60}h')
                              .tr()
                        ]),
                        selected: _coolMinutes == m,
                        accent: accent,
                        onTap: () => _update(() => _coolMinutes = m))),
              ],
            ])),
      ],
      const SizedBox(height: 24),
      ScheduleSection(
          label: 'routine_field_repeat'.tr(),
          gap: 8,
          child: Row(children: [
            for (var d = 1; d <= 7; d++) ...[
              if (d > 1) const SizedBox(width: 4),
              Expanded(
                  child: ScheduleChoiceChip(
                      key: Key('routine_day_$d'),
                      label: 'routine_day_$d'.tr(),
                      selected: _days.contains(d),
                      accent: accent,
                      onTap: () => _update(() => _days.contains(d)
                          ? _days.remove(d)
                          : _days.add(d)))),
            ],
          ])),
    ]);
  }
}

/// 라벨(16/500 #949090, 왼쪽 12) + [gap] + 내용.
class ScheduleSection extends StatelessWidget {
  const ScheduleSection(
      {super.key, required this.label, required this.child, this.gap = 4});
  final String label;
  final Widget child;
  final double gap;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(label,
                style: managementStyle(context,
                    color: context.glass.textTertiary))),
        SizedBox(height: gap),
        child,
      ]);
}

/// 오전/오후 86×70 + 시 108×118 + ":" + 분 108×118 = 345 (Figma 1106:7234).
class ScheduleTimeRow extends StatelessWidget {
  const ScheduleTimeRow(
      {super.key,
      required this.prefix,
      required this.clock,
      required this.accent,
      required this.onChanged});
  final String prefix;
  final ScheduleClock clock;
  final Color accent;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget half(
            String key, String text, bool selected, VoidCallback onTap) =>
        Material(
            color: selected ? accent : glass.surfaceHeader,
            child: InkWell(
                key: Key(key),
                onTap: onTap,
                child: SizedBox(
                    width: 86,
                    height: 35,
                    child: Center(
                        child: Text(
                            text,
                            style: managementStyle(
                                context,
                                weight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: selected
                                    ? ManagementColors.buttonForeground(context)
                                    : glass.textSecondary))))));
    return SizedBox(
        height: 118,
        child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                half('${prefix}_am', 'routine_am'.tr(), !clock.pm, () {
                  clock.pm = false;
                  onChanged();
                }),
                half('${prefix}_pm', 'routine_pm'.tr(), clock.pm, () {
                  clock.pm = true;
                  onChanged();
                }),
              ])),
          const SizedBox(width: 20),
          _Picker(
              prefix: '${prefix}_hour',
              text: '${clock.hour12}',
              onStep: (d) {
                clock.stepHour(d);
                onChanged();
              }),
          SizedBox(
              width: 23,
              child: Center(
                  child: Text(':',
                      style: managementStyle(context,
                          size: 24,
                          weight: FontWeight.w600,
                          color: glass.textSecondary)))),
          _Picker(
              prefix: '${prefix}_minute',
              text: clock.minute.toString().padLeft(2, '0'),
              onStep: (d) {
                clock.stepMinute(d);
                onChanged();
              }),
        ]));
  }
}

/// 위 화살표 24 + 값 상자 108×70(#E3E3E3, r8, 24/600) + 아래 화살표 24.
class _Picker extends StatelessWidget {
  const _Picker(
      {required this.prefix, required this.text, required this.onStep});
  final String prefix;
  final String text;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget arrow(String key, bool up) => InkWell(
        key: Key(key),
        onTap: () => onStep(up ? 1 : -1),
        child: SizedBox(
            width: 108,
            height: 24,
            child: Center(
                child: FigmaIcon.tinted(
                    up
                        ? FigmaIcons.keyboardArrowUp
                        : FigmaIcons.keyboardArrowDown,
                    size: 12,
                    height: 7,
                    color: glass.textSecondary))));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      arrow('${prefix}_up', true),
      Container(
          width: 108,
          height: 70,
          decoration: BoxDecoration(
              color: glass.border, borderRadius: BorderRadius.circular(8)),
          child: Center(
              child: Text(text,
                  key: Key(prefix),
                  style: managementStyle(context,
                      size: 24,
                      weight: FontWeight.w600,
                      color: glass.textPrimary)))),
      arrow('${prefix}_down', false),
    ]);
  }
}

/// 44 높이 r16 칩 — 선택은 기기색 바탕 + 흰 글자(오전/오후와 같은 문법).
/// 제어 시트의 작동 시간 칩(Figma 1106:4296)도 같은 규격이다. [enabled]가
/// false면 회색 면(#E3E3E3)·회색 글자(잠금 프레임 1106:6362 문법).
class ScheduleChoiceChip extends StatelessWidget {
  const ScheduleChoiceChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.accent,
      required this.onTap,
      this.enabled = true});
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final fill = !enabled
        ? (selected ? glass.deviceOff : glass.border)
        : selected
            ? accent
            : glass.surfaceHeader;
    final fg = !enabled
        ? (selected
            ? ManagementColors.buttonForeground(context)
            : glass.textTertiary)
        : selected
            ? ManagementColors.buttonForeground(context)
            : glass.textSecondary;
    return Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: SizedBox(
                height: 44,
                child: Center(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: managementStyle(context,
                            weight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: fg))))));
  }
}
