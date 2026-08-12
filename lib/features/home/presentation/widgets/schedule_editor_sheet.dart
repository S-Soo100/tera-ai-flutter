import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/mist_duration.dart';
import '../../domain/schedule.dart';

/// 편집기가 돌려주는 값. 화면이 그대로 repository에 넘긴다.
class ScheduleDraft {
  final ScheduleAction action;
  final ScheduleKind kind;
  final int hour;
  final int minute;
  final List<int> daysOfWeek;
  final Map<String, dynamic>? payload;

  const ScheduleDraft({
    required this.action,
    required this.kind,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    required this.payload,
  });
}

/// 예약 추가·수정 시트.
///
/// [initial]이 있으면 수정이다. **이때 동작은 못 바꾼다** — 서버가 `action`
/// 수정을 안 받는다(`APP_TIMER_MIST.md` §2.3). 바꾸려면 지우고 새로 만든다.
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
  late ScheduleAction _action;
  late ScheduleKind _kind;
  late TimeOfDay _time;
  late Set<int> _days;
  late MistDuration _duration;

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
  }

  bool get _valid =>
      Schedule.validate(kind: _kind, daysOfWeek: _days.toList());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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

            // ── 동작 ────────────────────────────────────────────────────
            Text('routine_field_action'.tr(),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppStyles.spacing8),
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

            // ── 분사 시간 (분무만) ──────────────────────────────────────
            if (_action.requiresDuration) ...[
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
              title: Text('routine_field_time'.tr()),
              trailing: Text(
                '${_time.hour.toString().padLeft(2, '0')}:'
                '${_time.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: _pickTime,
            ),

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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  void _save() {
    Navigator.of(context).pop(ScheduleDraft(
      action: _action,
      kind: _kind,
      hour: _time.hour,
      minute: _time.minute,
      daysOfWeek: _days.toList()..sort(),
      payload: _action.requiresDuration ? _duration.payload : null,
    ));
  }

}
