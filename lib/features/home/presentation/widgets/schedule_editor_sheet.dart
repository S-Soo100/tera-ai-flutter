import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../my_cage/presentation/management_colors.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../../domain/mist_duration.dart';
import '../../domain/schedule.dart';
import '../../domain/schedule_device.dart';
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

/// 12시간제 한 칸 — 오전/오후 + 1~12시 + 분. 서버 24시간제와 여기서만 오간다.
class _Clock {
  _Clock(int hour24, this.minute)
      : pm = hour24 >= 12,
        hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

  bool pm;
  int hour12;
  int minute;

  int get hour24 => (hour12 % 12) + (pm ? 12 : 0);

  /// 시는 1~12를 돈다. 오전/오후는 버튼이 따로 있어 시가 넘어가도 안 바뀐다.
  void stepHour(int delta) =>
      hour12 = ((hour12 - 1 + delta) % 12 + 12) % 12 + 1;

  /// 분은 5분 단위로 돈다. 5분 단위가 아닌 기존 값은 화살표 한 번에 가까운
  /// 5분 눈금으로 들어간다.
  void stepMinute(int delta) {
    final base = delta > 0 ? (minute ~/ 5) * 5 : ((minute + 4) ~/ 5) * 5;
    minute = ((base + delta * 5) % 60 + 60) % 60;
  }
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  late final ScheduleDevice? _device;
  late final ScheduleEditorKind _kind;
  late final _Clock _start;
  late final _Clock _end;
  int? _coolMinutes;
  late final Set<int> _days;

  bool get _isEdit => widget.initial != null || widget.initialPair != null;

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
    _kind = pair != null
        ? (_device?.kind == ScheduleEditorKind.duration
            ? ScheduleEditorKind.duration
            : ScheduleEditorKind.span)
        : widget.initial != null
            ? ScheduleEditorKind.point
            : widget.device!.kind;
    // Figma 예시(오후 12:00 → 오후 2:00)를 새 예약의 출발값으로 쓴다.
    _start = _Clock(base?.hour ?? 12, base?.minute ?? 0);
    _end = _Clock(pair?.off.hour ?? 14, pair?.off.minute ?? 0);
    if (_kind == ScheduleEditorKind.duration) {
      if (pair == null) {
        _coolMinutes = ScheduleDevice.coolDurations.first;
      } else {
        // 기존 구간 길이가 30/60/120분이면 그 칩, 아니면 미선택(고르기 전엔
        // 저장 불가) — 원본에 없는 값을 만들어 넣지 않는다.
        final diff = ((pair.off.hour * 60 + pair.off.minute) -
                    (pair.on.hour * 60 + pair.on.minute)) %
                (24 * 60) +
            0;
        _coolMinutes =
            ScheduleDevice.coolDurations.contains(diff) ? diff : null;
      }
    }
    _days = {...?base?.daysOfWeek};
  }

  bool get _valid =>
      _kind != ScheduleEditorKind.duration || _coolMinutes != null;

  Color _accent(BuildContext context) =>
      scheduleDeviceColor(context, _device) ?? context.glass.textPrimary;

  String _title() {
    final name = _device?.nameKey.tr() ?? _action.displayKey.tr();
    return 'routine_device_title_fmt'.tr(args: [name]);
  }

  void _save() {
    final kind = _days.isEmpty ? ScheduleKind.daily : ScheduleKind.weekly;
    final days = _days.toList()..sort();
    final pair = widget.initialPair;
    switch (_kind) {
      case ScheduleEditorKind.point:
        final action = _action;
        Navigator.pop(
            context,
            ScheduleDraft(
              action: action,
              kind: kind,
              hour: _start.hour24,
              minute: _start.minute,
              daysOfWeek: days,
              // 원본 편집기엔 분사 시간 선택이 없다 — 새 분무 예약은 홈 타일과
              // 같은 3초, 기존 예약은 저장된 값을 그대로 둔다.
              payload: widget.initial?.payload ??
                  (action.requiresDuration
                      ? {'duration_ms': MistDuration.threeSeconds.milliseconds}
                      : null),
            ));
      case ScheduleEditorKind.span:
      case ScheduleEditorKind.duration:
        var endHour = _end.hour24;
        var endMinute = _end.minute;
        if (_kind == ScheduleEditorKind.duration) {
          final total =
              (_start.hour24 * 60 + _start.minute + _coolMinutes!) % (24 * 60);
          endHour = total ~/ 60;
          endMinute = total % 60;
        }
        Navigator.pop(
            context,
            ScheduleDraft(
              action: pair?.on.action ?? _device!.onAction,
              offAction: pair?.off.action ?? _device!.offAction,
              kind: kind,
              hour: _start.hour24,
              minute: _start.minute,
              endHour: endHour,
              endMinute: endMinute,
              daysOfWeek: days,
              payload: null,
            ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final accent = _accent(context);
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
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Section(
                                  label: 'routine_start'.tr(),
                                  child: _TimeRow(
                                      prefix: 'routine_start',
                                      clock: _start,
                                      accent: accent,
                                      onChanged: () => setState(() {}))),
                              if (_kind == ScheduleEditorKind.span) ...[
                                const SizedBox(height: 24),
                                _Section(
                                    label: 'routine_end'.tr(),
                                    child: _TimeRow(
                                        prefix: 'routine_end',
                                        clock: _end,
                                        accent: accent,
                                        onChanged: () => setState(() {}))),
                              ],
                              if (_kind == ScheduleEditorKind.duration) ...[
                                const SizedBox(height: 24),
                                _Section(
                                    label: 'routine_end'.tr(),
                                    gap: 8,
                                    child: Row(children: [
                                      for (final (i, m) in ScheduleDevice
                                          .coolDurations.indexed) ...[
                                        if (i > 0) const SizedBox(width: 6),
                                        Expanded(
                                            child: _Chip(
                                                key: Key('routine_after_$m'),
                                                label: 'home_timer_later_fmt'
                                                    .tr(args: [
                                                  (m < 60
                                                          ? 'home_timer_${m}m'
                                                          : 'home_timer_${m ~/ 60}h')
                                                      .tr()
                                                ]),
                                                selected: _coolMinutes == m,
                                                accent: accent,
                                                onTap: () => setState(
                                                    () => _coolMinutes = m))),
                                      ],
                                    ])),
                              ],
                              const SizedBox(height: 24),
                              _Section(
                                  label: 'routine_field_repeat'.tr(),
                                  gap: 8,
                                  child: Row(children: [
                                    for (var d = 1; d <= 7; d++) ...[
                                      if (d > 1) const SizedBox(width: 4),
                                      Expanded(
                                          child: _Chip(
                                              key: Key('routine_day_$d'),
                                              label: 'routine_day_$d'.tr(),
                                              selected: _days.contains(d),
                                              accent: accent,
                                              onTap: () => setState(() =>
                                                  _days.contains(d)
                                                      ? _days.remove(d)
                                                      : _days.add(d)))),
                                    ],
                                  ])),
                            ]))),
              ])),
          Positioned(
              left: 12,
              right: 12,
              bottom: bottom + (_isEdit ? 10 : 66),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ManagementButton(
                    key: const Key('routine_save'),
                    label: 'routine_editor_save'.tr(),
                    onPressed: _valid ? _save : null),
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

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.gap = 4});
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
class _TimeRow extends StatelessWidget {
  const _TimeRow(
      {required this.prefix,
      required this.clock,
      required this.accent,
      required this.onChanged});
  final String prefix;
  final _Clock clock;
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
                child: CustomPaint(
                    size: const Size(24, 24),
                    painter:
                        _ChevronPainter(up: up, color: glass.textSecondary)))));
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

/// Figma keyboard_arrow_up/down(Material Symbols 24 그리드) — 레포에 export가
/// 없어 같은 경로 좌표를 직접 그린다(P17 표 기록).
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.up, required this.color});
  final bool up;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path();
    if (up) {
      path
        ..moveTo(7.41 * s, 15.41 * s)
        ..lineTo(12 * s, 10.83 * s)
        ..lineTo(16.59 * s, 15.41 * s)
        ..lineTo(18 * s, 14 * s)
        ..lineTo(12 * s, 8 * s)
        ..lineTo(6 * s, 14 * s)
        ..close();
    } else {
      path
        ..moveTo(7.41 * s, 8.59 * s)
        ..lineTo(12 * s, 13.17 * s)
        ..lineTo(16.59 * s, 8.59 * s)
        ..lineTo(18 * s, 10 * s)
        ..lineTo(12 * s, 16 * s)
        ..lineTo(6 * s, 10 * s)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.up != up || old.color != color;
}

/// 44 높이 r16 칩 — 선택은 기기색 바탕 + 흰 글자(오전/오후와 같은 문법).
class _Chip extends StatelessWidget {
  const _Chip(
      {super.key,
      required this.label,
      required this.selected,
      required this.accent,
      required this.onTap});
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Material(
        color: selected ? accent : glass.surfaceHeader,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
                height: 44,
                child: Center(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: managementStyle(context,
                            weight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected
                                ? ManagementColors.buttonForeground(context)
                                : glass.textSecondary))))));
  }
}
