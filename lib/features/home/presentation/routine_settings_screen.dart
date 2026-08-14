import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/glass_page_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/mist_duration.dart';
import '../domain/schedule.dart';
import 'schedule_providers.dart';
import 'widgets/schedule_editor_sheet.dart';

/// PRD §4.2 타이머 & 일정 설정 (풀스크린 모달).
///
/// **지금은 §4.2.2 "일정"의 시점 예약까지만이다.** 계약에 없는 것은 만들지
/// 않고 왜 없는지 화면에 밝힌다 — 빈 화면은 고장으로 읽힌다.
///
/// | PRD | 상태 |
/// |---|---|
/// | §4.2.1 타이머(즉시·일회성) | ✅ 팬 — 제어 그리드의 팬 시트에서 건다 (히터는 보드 미탑재) |
/// | §4.2.2 일정 — 시점 예약 | ✅ 여기 |
/// | §4.2.2 시작~종료 구간 | ✅ 편집기 [구간] — on/off 예약 2건 생성 |
/// | §4.2.2 스마트 조건 | ✅ 스킵형 4종 (정지형은 펌웨어 후속 — 하단 각주) |
///
/// 상세: `docs/backend-handoff-2026-08-14-summary.md` ·
/// `docs/plans/2026-08-14-backend-handoff-fan-timer-guard-lcd.md`
class RoutineSettingsScreen extends ConsumerWidget {
  const RoutineSettingsScreen({super.key});

  static const listKey = Key('routine_schedule_list');
  static const addKey = Key('routine_add_schedule');
  static const pendingFootnoteKey = Key('routine_pending_footnote');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(schedulesProvider);

    // A안 경량 전환 — 배경·표면 톤만 유리 문법으로. 예약 로직 불변.
    return GlassPageShell(
        child: Scaffold(
      appBar: AppBar(title: Text('home_routine_settings'.tr())),
      // `/home/routines`는 탭 셸 **밖** 최상위 라우트다(app_router.dart '탭 셸
      // 밖' 참조) — 독이 없으니 FAB를 들어올릴 것도 없다. Scaffold가 세이프
      // 에어리어는 알아서 반영한다.
      floatingActionButton: FloatingActionButton.extended(
        key: addKey,
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text('routine_add'.tr()),
      ),
      body: ListView(
        // 하단 96 = FAB 높이 48 + FAB 기본 마진 16 + 여유 32 — 마지막 예약
        // 줄이 FAB에 가려지지 않게. (독은 없다 — 위 라우트 주석 참조)
        padding: const EdgeInsets.fromLTRB(AppStyles.spacing16,
            AppStyles.spacing16, AppStyles.spacing16, 96),
        children: [
          Text('routine_schedule_section'.tr(),
              style: AppStyles.subsectionTitle(context)),
          const SizedBox(height: AppStyles.spacing8),
          schedules.when(
            loading: () => const SkeletonListLoading(itemCount: 3),
            error: (e, _) => _ErrorNote(message: '$e'),
            data: (list) => list.isEmpty
                ? _EmptyNote()
                : Column(
                    key: listKey,
                    children: [
                      for (final s in list)
                        _ScheduleTile(
                          schedule: s,
                          onToggle: (v) => _guard(
                              context, () => ref
                                  .read(schedulesProvider.notifier)
                                  .setEnabled(s, v)),
                          onDelete: () => _confirmDelete(context, ref, s),
                          onEdit: () => _edit(context, ref, s),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppStyles.spacing24),
          // 계약이 없어 못 만드는 것 — 빈 자리를 이유 없이 두면 고장으로 읽힌다.
          Text(
            'routine_pending_footnote'.tr(),
            key: pendingFootnoteKey,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ));
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showScheduleEditor(context);
    if (result == null || !context.mounted) return;
    await _guard(
      context,
      () => result.isSpan
          ? ref.read(schedulesProvider.notifier).addSpan(
                onAction: result.action,
                offAction: result.offAction!,
                kind: result.kind,
                startHour: result.hour,
                startMinute: result.minute,
                endHour: result.endHour!,
                endMinute: result.endMinute!,
                daysOfWeek: result.daysOfWeek,
                guard: result.guard,
              )
          : ref.read(schedulesProvider.notifier).add(
                action: result.action,
                kind: result.kind,
                hour: result.hour,
                minute: result.minute,
                daysOfWeek: result.daysOfWeek,
                payload: result.payload,
                guard: result.guard,
              ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Schedule s) async {
    // `action`은 서버가 수정을 안 받는다. 편집기는 타이밍·가드만 바꾸게 하고,
    // 동작을 바꾸려면 지우고 새로 만들어야 한다.
    final result = await showScheduleEditor(context, initial: s);
    if (result == null || !context.mounted) return;
    await _guard(
      context,
      () => ref.read(schedulesProvider.notifier).updateTiming(
            s,
            kind: result.kind,
            hour: result.hour,
            minute: result.minute,
            daysOfWeek: result.daysOfWeek,
            payload: result.payload,
            guard: result.guard,
            clearGuard: result.clearGuard,
          ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Schedule s) async {
    // 끄기 예약을 지우는데 짝이 될 켜기 예약이 살아 있으면 경고를 바꾼다 —
    // 서버에 쌍 개념이 없어(구간 예약 = 낱개 2건) 이 목록 검사로만 잡을 수
    // 있다. 켜기만 남으면 기기가 켜진 채 방치된다(히터면 과열).
    final others = ref.read(schedulesProvider).valueOrNull ?? const [];
    final leavesOrphanOn = s.action.isOffAction &&
        others.any((e) =>
            e.id != s.id && e.enabled && e.action == s.action.onCounterpart);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('routine_delete_title'.tr()),
        content: Text(
          (leavesOrphanOn ? 'routine_delete_off_warning' : 'routine_delete_body')
              .tr(),
          key: leavesOrphanOn
              ? const Key('routine_delete_off_warning')
              : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('routine_delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _guard(
        context, () => ref.read(schedulesProvider.notifier).remove(s));
  }

  /// 실패를 삼키지 않는다. 예약은 "됐겠지"로 넘길 수 있는 동작이 아니다 —
  /// 사용자는 기기가 알아서 돌 거라 믿고 신경을 끈다.
  static Future<void> _guard(
      BuildContext context, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('routine_action_failed'.tr(args: ['$e']))),
      );
    }
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final Schedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('schedule_${schedule.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${schedule.hhmm}  ${schedule.action.displayKey.tr()}'
        '${_durationSuffix()}',
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        [
          _repeatLabel(),
          if (schedule.guard case final g? when g.enabled)
            _guardLabel(g),
          if (schedule.nextRunAt != null && schedule.enabled)
            'routine_next_run'.tr(args: [_formatNext(schedule.nextRunAt!)]),
        ].join(' · '),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: Key('schedule_toggle_${schedule.id}'),
            value: schedule.enabled,
            onChanged: onToggle,
          ),
          IconButton(
            key: Key('schedule_delete_${schedule.id}'),
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _durationSuffix() {
    final ms = schedule.payload?['duration_ms'];
    if (ms is! num) return '';
    return ' ${MistDuration.fromMilliseconds(ms.toInt()).seconds}'
        '${'routine_seconds_suffix'.tr()}';
  }

  String _repeatLabel() {
    if (schedule.kind == ScheduleKind.daily) return 'routine_daily'.tr();
    return schedule.daysOfWeek.map((d) => _dayName(d)).join('·');
  }

  /// `습도>70%면 건너뜀` 식. 키는 `routine_guard_chip_<wire 뒷부분>`.
  static String _guardLabel(ScheduleGuard g) {
    final key =
        'routine_guard_chip_${g.type.wire.substring('skip_when_'.length)}';
    final v = g.value == g.value.roundToDouble()
        ? '${g.value.toInt()}'
        : '${g.value}';
    return key.tr(args: [v]);
  }

  static String _dayName(int d) => 'routine_day_$d'.tr();

  /// 이미 로컬로 바꿔 보관한 값이라 여기서 시차를 더하지 않는다.
  static String _formatNext(DateTime at) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final hhmm = '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'routine_today_at'.tr(args: [hhmm]);
    return '${at.month}/${at.day} $hhmm';
  }
}

class _EmptyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing16),
      child: Text(
        'routine_schedule_empty'.tr(),
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing16),
      child: Text(
        'routine_load_failed'.tr(args: [message]),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}
