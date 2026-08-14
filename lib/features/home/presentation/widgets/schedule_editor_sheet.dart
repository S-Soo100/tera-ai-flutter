import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/mist_duration.dart';
import '../../domain/schedule.dart';

/// 편집기가 돌려주는 값. 화면이 그대로 notifier에 넘긴다.
///
/// [offAction]이 있으면 **구간 예약**이다 — 화면이 `addSpan`으로 분기해
/// on/off 2건을 만든다(서버에 쌍 개념이 없어 생성 헬퍼일 뿐이다).
class ScheduleDraft {
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

/// 구간 예약에서 고르는 기기. 분무는 정량([ScheduleAction.mist])이라 구간이 없다.
enum _SpanActuator {
  fan(ScheduleAction.fanOn, ScheduleAction.fanOff),
  heater(ScheduleAction.heaterOn, ScheduleAction.heaterOff),
  led(ScheduleAction.ledOn, ScheduleAction.ledOff);

  const _SpanActuator(this.onAction, this.offAction);

  final ScheduleAction onAction;
  final ScheduleAction offAction;

  String get labelKey => 'routine_span_$name';
}

/// 가드 종류 선택 라벨. `skip_when_humidity_above` → `routine_guard_humidity_above`.
String _guardPickKey(GuardType t) =>
    'routine_guard_${t.wire.substring('skip_when_'.length)}';

/// 예약 추가·수정 시트.
///
/// [initial]이 있으면 수정이다. **이때 동작·구간은 못 바꾼다** — 서버가 `action`
/// 수정을 안 받고(`APP_TIMER_MIST.md` §2.3), 구간은 쌍 개념이 없어 낱개로만
/// 수정된다. 타이밍·가드만 바꿀 수 있다.
Future<ScheduleDraft?> showScheduleEditor(
  BuildContext context, {
  Schedule? initial,
}) {
  return showModalBottomSheet<ScheduleDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ScheduleEditor(initial: initial),
  );
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.initial});

  final Schedule? initial;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  bool _isSpan = false;
  late ScheduleAction _action;
  _SpanActuator _spanActuator = _SpanActuator.fan;
  late ScheduleKind _kind;
  late TimeOfDay _time;
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  late Set<int> _days;
  late MistDuration _duration;

  GuardType? _guardType;
  late final TextEditingController _guardValue;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _action = i?.action ?? ScheduleAction.mist;
    _kind = i?.kind ?? ScheduleKind.daily;
    _time = TimeOfDay(hour: i?.hour ?? 8, minute: i?.minute ?? 0);
    _days = {...?i?.daysOfWeek};
    _duration = MistDuration.fromMilliseconds(
      (i?.payload?['duration_ms'] as num?)?.toInt(),
    );
    _guardType = i?.guard?.type;
    _guardValue = TextEditingController(
      text: i?.guard == null ? '' : _fmtNum(i!.guard!.value),
    );
  }

  @override
  void dispose() {
    _guardValue.dispose();
    super.dispose();
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  double? get _parsedGuardValue => double.tryParse(_guardValue.text.trim());

  bool get _guardValid {
    if (_guardType == null) return true;
    final v = _parsedGuardValue;
    if (v == null) return false;
    if (_guardType!.isHumidity && (v < 0 || v > 100)) return false;
    return true;
  }

  bool get _valid =>
      Schedule.validate(kind: _kind, daysOfWeek: _days.toList()) && _guardValid;

  ScheduleGuard? get _guard => _guardType == null
      ? null
      : ScheduleGuard(type: _guardType!, value: _parsedGuardValue!, enabled: true);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppStyles.spacing16,
          right: AppStyles.spacing16,
          top: AppStyles.spacing16,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppStyles.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'routine_edit_title'.tr() : 'routine_add_title'.tr(),
              style: AppStyles.subsectionTitle(context),
            ),
            const SizedBox(height: AppStyles.spacing16),

            // ── 시점/구간 (추가에서만 — 구간은 쌍이 없어 수정 불가) ──────
            if (!_isEdit) ...[
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text('routine_mode_point'.tr()),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('routine_mode_span'.tr()),
                  ),
                ],
                selected: {_isSpan},
                onSelectionChanged: (s) => setState(() => _isSpan = s.first),
              ),
              const SizedBox(height: AppStyles.spacing16),
            ],

            // ── 동작 (시점) / 기기 (구간) ────────────────────────────────
            Text(
              (_isSpan ? 'routine_span_actuator' : 'routine_field_action').tr(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppStyles.spacing8),
            if (_isSpan)
              Wrap(
                spacing: AppStyles.spacing8,
                children: [
                  for (final a in _SpanActuator.values)
                    ChoiceChip(
                      key: Key('routine_span_${a.name}'),
                      label: Text(a.labelKey.tr()),
                      selected: _spanActuator == a,
                      onSelected: (_) => setState(() => _spanActuator = a),
                    ),
                ],
              )
            else
              Wrap(
                spacing: AppStyles.spacing8,
                children: [
                  for (final a in ScheduleAction.selectable)
                    ChoiceChip(
                      key: Key('routine_action_${a.wire}'),
                      label: Text(a.displayKey.tr()),
                      selected: _action == a,
                      // 수정 중엔 잠근다 — 서버가 안 받는 변경을 눌러보게 하면
                      // 실패 토스트로만 알게 된다.
                      onSelected:
                          _isEdit ? null : (_) => setState(() => _action = a),
                    ),
                ],
              ),
            if (_isEdit) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                'routine_action_locked'.tr(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (_isSpan && _spanActuator == _SpanActuator.heater) ...[
              const SizedBox(height: AppStyles.spacing8),
              Text(
                'routine_span_heater_warn'.tr(),
                key: const Key('routine_span_heater_warn'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],

            // ── 분사 시간 (시점·분무만) ────────────────────────────────
            if (!_isSpan && _action.requiresDuration) ...[
              const SizedBox(height: AppStyles.spacing16),
              Text('routine_field_duration'.tr(),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppStyles.spacing8),
              Wrap(
                spacing: AppStyles.spacing8,
                children: [
                  for (final d in MistDuration.values)
                    ChoiceChip(
                      key: Key('routine_duration_${d.seconds}'),
                      label: Text('home_mist_seconds'
                          .tr(args: ['${d.seconds}'])),
                      selected: _duration == d,
                      onSelected: (_) => setState(() => _duration = d),
                    ),
                ],
              ),
            ],

            // ── 반복 ────────────────────────────────────────────────────
            const SizedBox(height: AppStyles.spacing16),
            Text('routine_field_repeat'.tr(),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppStyles.spacing8),
            SegmentedButton<ScheduleKind>(
              segments: [
                ButtonSegment(
                  value: ScheduleKind.daily,
                  label: Text('routine_daily'.tr()),
                ),
                ButtonSegment(
                  value: ScheduleKind.weekly,
                  label: Text('routine_weekly'.tr()),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            if (_kind == ScheduleKind.weekly) ...[
              const SizedBox(height: AppStyles.spacing8),
              Wrap(
                spacing: AppStyles.spacing8,
                children: [
                  // 1=월 … 7=일. Dart DateTime.weekday와 같은 규칙이다.
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      key: Key('routine_day_$d'),
                      label: Text('routine_day_$d'.tr()),
                      selected: _days.contains(d),
                      onSelected: (v) => setState(
                          () => v ? _days.add(d) : _days.remove(d)),
                    ),
                ],
              ),
            ],

            // ── 시각 ────────────────────────────────────────────────────
            const SizedBox(height: AppStyles.spacing16),
            ListTile(
              key: const Key('routine_pick_time'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                  (_isSpan ? 'routine_span_start' : 'routine_field_time').tr()),
              trailing: Text(
                _hhmm(_time),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _pickTime(start: true),
            ),
            if (_isSpan)
              // 자정 넘김 허용 — daily 2건이라 "22:00 켜고 06:00 끄기"가
              // 자연스럽게 동작한다. 시작>종료를 막지 않는다.
              ListTile(
                key: const Key('routine_pick_end_time'),
                contentPadding: EdgeInsets.zero,
                title: Text('routine_span_end'.tr()),
                trailing: Text(
                  _hhmm(_endTime),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _pickTime(start: false),
              ),

            // ── 스마트 조건 (가드) ──────────────────────────────────────
            const SizedBox(height: AppStyles.spacing16),
            Text('routine_guard_section'.tr(),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppStyles.spacing8),
            Wrap(
              spacing: AppStyles.spacing8,
              children: [
                ChoiceChip(
                  key: const Key('routine_guard_off'),
                  label: Text('routine_guard_off'.tr()),
                  selected: _guardType == null,
                  onSelected: (_) => setState(() => _guardType = null),
                ),
                for (final t in GuardType.values)
                  ChoiceChip(
                    key: Key('routine_guard_${t.wire}'),
                    label: Text(_guardPickKey(t).tr()),
                    selected: _guardType == t,
                    onSelected: (_) => setState(() {
                      _guardType = t;
                      if (_guardValue.text.trim().isEmpty) {
                        // 종별 상식값이 아니라 "일단 유효한 값"이다 — 사용자가
                        // 자기 사육장 기준으로 고치는 출발점.
                        _guardValue.text = t.isHumidity ? '70' : '30';
                      }
                    }),
                  ),
              ],
            ),
            if (_guardType != null) ...[
              const SizedBox(height: AppStyles.spacing8),
              TextField(
                key: const Key('routine_guard_value'),
                controller: _guardValue,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: (_guardType!.isHumidity
                          ? 'routine_guard_value_humidity'
                          : 'routine_guard_value_temp')
                      .tr(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: AppStyles.spacing16),
            FilledButton(
              key: const Key('routine_save'),
              onPressed: _valid ? _save : null,
              child: Text(_isEdit
                  ? 'routine_save_edit'.tr()
                  : 'routine_save_add'.tr()),
            ),
            if (!_valid) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                'routine_need_days'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
        context: context, initialTime: start ? _time : _endTime);
    if (picked == null || !mounted) return;
    setState(() => start ? _time = picked : _endTime = picked);
  }

  void _save() {
    final span = !_isEdit && _isSpan;
    Navigator.of(context).pop(ScheduleDraft(
      action: span ? _spanActuator.onAction : _action,
      offAction: span ? _spanActuator.offAction : null,
      kind: _kind,
      hour: _time.hour,
      minute: _time.minute,
      endHour: span ? _endTime.hour : null,
      endMinute: span ? _endTime.minute : null,
      daysOfWeek: _days.toList()..sort(),
      payload: !span && _action.requiresDuration ? _duration.payload : null,
      guard: _guard,
      // 수정에서 원래 가드가 있었는데 '사용 안 함'으로 껐다 → 명시적 해제.
      clearGuard: _isEdit && widget.initial?.guard != null && _guardType == null,
    ));
  }
}
