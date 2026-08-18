import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../shared/domain/num_format.dart';
import '../../domain/mist_duration.dart';
import '../../domain/schedule.dart';

/// 편집기가 돌려주는 값. 화면이 그대로 notifier에 넘긴다.
///
/// [offAction]이 있으면 **구간 예약**이다 — 화면이 `addSpan`/`updateSpanTiming`
/// 으로 분기해 같은 `pair_id`의 on/off 2건을 만들거나 고친다.
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

  /// 켜기 동작으로 역추적. 구간 편집에서 잠긴 칩을 그리는 데 쓴다.
  static _SpanActuator? fromOnAction(ScheduleAction a) {
    for (final v in values) {
      if (v.onAction == a) return v;
    }
    return null;
  }
}

/// 가드 종류 선택 라벨. `skip_when_humidity_above` → `routine_guard_humidity_above`.
String _guardPickKey(GuardType t) =>
    'routine_guard_${t.wire.substring('skip_when_'.length)}';

/// 예약 추가·수정 시트.
///
/// [initial](시점) 또는 [initialPair](구간)가 있으면 수정이다. **이때 동작은
/// 못 바꾼다** — 서버가 `action` 수정을 안 받는다(`APP_TIMER_MIST.md` §2.3).
/// 타이밍·가드만 바꿀 수 있고, 구간은 시작·종료 둘 다 고칠 수 있다.
Future<ScheduleDraft?> showScheduleEditor(
  BuildContext context, {
  Schedule? initial,
  SchedulePair? initialPair,
}) {
  assert(initial == null || initialPair == null);
  return showModalBottomSheet<ScheduleDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) =>
        _ScheduleEditor(initial: initial, initialPair: initialPair),
  );
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.initial, this.initialPair});

  final Schedule? initial;
  final SchedulePair? initialPair;

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

  /// 사용자가 가드 섹션을 실제로 건드렸는가.
  ///
  /// 수정에서 안 건드렸으면 PATCH에 guard 키를 **아예 싣지 않아** 서버 값이
  /// 그대로 남는다 — 여기서 `enabled:true`로 다시 만들어 보내면, 꺼져 있던
  /// 가드(enabled:false, 웹 콘솔 등에서 설정)가 시간만 고쳐도 재무장된다.
  bool _guardTouched = false;

  bool get _isEdit => widget.initial != null || widget.initialPair != null;

  /// 수정 대상의 원래 가드(시점이면 그 행, 구간이면 on행).
  ScheduleGuard? get _initialGuard =>
      widget.initial?.guard ?? widget.initialPair?.on.guard;

  /// 이 예약에 가드를 걸 수 있는가. **끄기 계열이면 금지** — 조건 때문에
  /// 끄기가 스킵되면 기기가 켜진 채 남는다(addSpan이 off쪽에 가드를 안 거는
  /// 것과 같은 불변식을 편집 경로에도 적용). 구간 모드는 가드가 켜기쪽에만
  /// 붙으므로 항상 허용.
  bool get _allowsGuard => _isSpan || !_action.isOffAction;

  @override
  void initState() {
    super.initState();
    final pair = widget.initialPair;
    // 구간 편집이면 on행이 기준, off행은 종료 시각만 준다.
    final i = widget.initial ?? pair?.on;
    if (pair != null) {
      _isSpan = true;
      _spanActuator =
          _SpanActuator.fromOnAction(pair.on.action) ?? _SpanActuator.fan;
      _endTime = TimeOfDay(hour: pair.off.hour, minute: pair.off.minute);
    }
    _action = i?.action ?? ScheduleAction.mist;
    _kind = i?.kind ?? ScheduleKind.daily;
    _time = TimeOfDay(hour: i?.hour ?? 8, minute: i?.minute ?? 0);
    _days = {...?i?.daysOfWeek};
    _duration = MistDuration.fromMilliseconds(
      (i?.payload?['duration_ms'] as num?)?.toInt(),
    );
    _guardType = i?.guard?.type;
    _guardValue = TextEditingController(
      text: i?.guard == null
          ? ''
          : formatCompact(i!.guard!.value, maxFractionDigits: 2),
    );
  }

  @override
  void dispose() {
    _guardValue.dispose();
    super.dispose();
  }

  double? get _parsedGuardValue => double.tryParse(_guardValue.text.trim());

  bool get _guardValid {
    // 가드를 못 거는 예약(끄기 계열)은 가드 값이 저장에 실리지 않으니
    // 검증도 걸지 않는다 — 섹션이 숨어 있어 사용자가 고칠 방법이 없다.
    if (!_allowsGuard) return true;
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

            // ── 시점/구간 (추가에서만 — 수정은 종류를 못 바꾼다) ──────
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
                      // 수정 중엔 잠근다 — action은 서버가 안 받는다.
                      onSelected: _isEdit
                          ? null
                          : (_) => setState(() => _spanActuator = a),
                    ),
                ],
              )
            else
              Wrap(
                spacing: AppStyles.spacing8,
                children: [
                  // 수정 대상이 selectable 밖의 동작(기존 toggle 예약 등)이면
                  // 그 칩을 함께 그린다 — 안 그리면 어떤 동작의 예약인지 시트가
                  // 보여주지 못한다(잠긴 칩이 선택된 채 보이는 게 원래 약속).
                  for (final a in [
                    ...ScheduleAction.selectable,
                    if (_isEdit &&
                        !ScheduleAction.selectable.contains(_action))
                      _action,
                  ])
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
            if (!_allowsGuard)
              Text(
                'routine_guard_not_for_off'.tr(),
                key: const Key('routine_guard_not_for_off'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            else ...[
              Wrap(
                spacing: AppStyles.spacing8,
                children: [
                  ChoiceChip(
                    key: const Key('routine_guard_off'),
                    label: Text('routine_guard_off'.tr()),
                    selected: _guardType == null,
                    onSelected: (_) => setState(() {
                      _guardType = null;
                      _guardTouched = true;
                    }),
                  ),
                  for (final t in GuardType.values)
                    ChoiceChip(
                      key: Key('routine_guard_${t.wire}'),
                      label: Text(_guardPickKey(t).tr()),
                      selected: _guardType == t,
                      onSelected: (_) => setState(() {
                        // 단위가 바뀌면(습도%↔온도°C) 값을 새 기본값으로 리셋 —
                        // 70%를 70°C로 그대로 들고 가면 절대 발화하지 않는
                        // 무력 가드가 조용히 만들어진다.
                        final prevUnit =
                            (_guardType ?? _initialGuard?.type)?.isHumidity;
                        _guardType = t;
                        _guardTouched = true;
                        if (_guardValue.text.trim().isEmpty ||
                            (prevUnit != null && prevUnit != t.isHumidity)) {
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
                  onChanged: (_) => setState(() => _guardTouched = true),
                ),
              ],
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
                // 막힌 이유를 그대로 말한다 — daily에서 가드 값이 틀렸는데
                // "요일을 골라라"가 뜨면 사용자는 풀 방법을 찾을 수 없다.
                (!Schedule.validate(kind: _kind, daysOfWeek: _days.toList())
                        ? 'routine_need_days'
                        : 'routine_guard_value_invalid')
                    .tr(),
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
    final span = _isSpan;
    // 수정에서 가드를 안 건드렸으면 null(키 생략) — 서버 값이 enabled까지
    // 그대로 남는다. 끄기 계열이면 어떤 경로로도 가드를 싣지 않는다.
    final emitsGuard = _allowsGuard && (!_isEdit || _guardTouched);
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
      guard: emitsGuard ? _guard : null,
      // 수정에서 원래 가드가 있었는데 직접 '사용 안 함'으로 껐다 → 명시적 해제.
      clearGuard: _isEdit &&
          _guardTouched &&
          _initialGuard != null &&
          _guardType == null,
    ));
  }
}
