import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/domain/num_format.dart';
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
/// | §4.2.2 시작~종료 구간 | ✅ 편집기 [구간] — 같은 `pair_id`의 on/off 2건, 목록엔 한 줄 |
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
                      // 같은 pair_id의 on/off는 한 줄로(2026-08-18 회신 §3).
                      for (final row in Schedule.group(list))
                        if (row case final SchedulePair p)
                          _PairTile(
                            pair: p,
                            onToggle: (v) => _guard(
                                context, () => ref
                                    .read(schedulesProvider.notifier)
                                    .setPairEnabled(p, v)),
                            onDelete: () => _confirmDeletePair(context, ref, p),
                            onEdit: () => _editPair(context, ref, p),
                          )
                        else if (row case final Schedule s)
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

  Future<void> _editPair(
      BuildContext context, WidgetRef ref, SchedulePair p) async {
    final result = await showScheduleEditor(context, initialPair: p);
    if (result == null || !context.mounted) return;
    await _guard(
      context,
      () => ref.read(schedulesProvider.notifier).updateSpanTiming(
            p,
            kind: result.kind,
            startHour: result.hour,
            startMinute: result.minute,
            endHour: result.endHour!,
            endMinute: result.endMinute!,
            daysOfWeek: result.daysOfWeek,
            guard: result.guard,
            clearGuard: result.clearGuard,
          ),
    );
  }

  /// 구간 삭제 — 서버가 짝을 같이 지운다는 걸 확인문에 밝힌다.
  Future<void> _confirmDeletePair(
      BuildContext context, WidgetRef ref, SchedulePair p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('routine_delete_title'.tr()),
        content: Text('routine_delete_pair_body'.tr(),
            key: const Key('routine_delete_pair_body')),
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
        context, () => ref.read(schedulesProvider.notifier).removePair(p));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Schedule s) async {
    // 끄기 예약을 지우는데 짝이 될 켜기 예약이 살아 있으면 경고를 바꾼다 —
    // pair_id 없는 낱개(2026-08-18 이전 구간, 웹 콘솔 생성)는 이 목록 검사로만
    // 잡을 수 있다. 켜기만 남으면 기기가 켜진 채 방치된다(히터면 과열).
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

/// 예약 목록 한 줄 공용 모양 — 시점([_ScheduleTile])·구간([_PairTile]) 둘 다
/// 이걸로 그린다. 제목·부제 조각·키·enabled만 다르고 트레일링(스위치+삭제)과
/// 스타일은 같아야 두 종류가 한 목록에서 어긋나지 않는다.
class _ScheduleRowTile extends StatelessWidget {
  const _ScheduleRowTile({
    required super.key,
    required this.title,
    required this.subtitleParts,
    required this.enabled,
    required this.toggleKey,
    required this.deleteKey,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final String title;
  final List<String> subtitleParts;
  final bool enabled;
  final Key toggleKey;
  final Key deleteKey;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitleParts.join(' · '),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(key: toggleKey, value: enabled, onChanged: onToggle),
          IconButton(
            key: deleteKey,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── 부제 조각 헬퍼 (시점·구간 공용) ─────────────────────────────────────────

String _repeatLabel(ScheduleKind kind, List<int> daysOfWeek) {
  if (kind == ScheduleKind.daily) return 'routine_daily'.tr();
  return daysOfWeek.map((d) => 'routine_day_$d'.tr()).join('·');
}

/// `습도>70%면 건너뜀` 식. 키는 `routine_guard_chip_<wire 뒷부분>`.
String _guardLabel(ScheduleGuard g) {
  final key =
      'routine_guard_chip_${g.type.wire.substring('skip_when_'.length)}';
  return key.tr(args: [formatCompact(g.value, maxFractionDigits: 2)]);
}

/// 이미 로컬로 바꿔 보관한 값이라 여기서 시차를 더하지 않는다.
String _formatNext(DateTime at) {
  final now = DateTime.now();
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  final hhmm = '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  if (sameDay) return 'routine_today_at'.tr(args: [hhmm]);
  return '${at.month}/${at.day} $hhmm';
}

String _nextRunLabel(DateTime? at) =>
    'routine_next_run'.tr(args: [_formatNext(at!)]);

/// 시점 예약 한 줄 — `08:00  분무 2초`.
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
    final s = schedule;
    return _ScheduleRowTile(
      key: Key('schedule_${s.id}'),
      title: '${s.hhmm}  ${s.action.displayKey.tr()}${_durationSuffix()}',
      subtitleParts: [
        _repeatLabel(s.kind, s.daysOfWeek),
        if (s.guard case final g? when g.enabled) _guardLabel(g),
        if (s.nextRunAt != null && s.enabled) _nextRunLabel(s.nextRunAt),
      ],
      enabled: s.enabled,
      toggleKey: Key('schedule_toggle_${s.id}'),
      deleteKey: Key('schedule_delete_${s.id}'),
      onToggle: onToggle,
      onDelete: onDelete,
      onEdit: onEdit,
    );
  }

  String _durationSuffix() {
    final ms = schedule.payload?['duration_ms'];
    if (ms is! num) return '';
    return ' ${MistDuration.fromMilliseconds(ms.toInt()).seconds}'
        '${'routine_seconds_suffix'.tr()}';
  }
}

/// 구간 한 줄 — `20:00 → 06:00  히터`. 반복·가드는 on행 기준, 다음 실행은
/// 두 행 중 먼저 오는 쪽. 반쪽 켜짐이면 경고 조각을 붙인다.
class _PairTile extends StatelessWidget {
  const _PairTile({
    required this.pair,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final SchedulePair pair;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final on = pair.on;
    final off = pair.off;
    final next = _earliest(on.nextRunAt, off.nextRunAt);
    return _ScheduleRowTile(
      key: Key('schedule_pair_${pair.pairId}'),
      // 시점 타일과 같은 조립 규칙(시각 + 라벨) — 화살표는 로케일 중립.
      title: '${on.hhmm} → ${off.hhmm}  ${on.action.labelKey.tr()}',
      subtitleParts: [
        _repeatLabel(on.kind, on.daysOfWeek),
        if (on.guard case final g? when g.enabled) _guardLabel(g),
        if (pair.isSkewed) 'routine_pair_skewed'.tr(),
        if (next != null && pair.enabled) _nextRunLabel(next),
      ],
      enabled: pair.enabled,
      toggleKey: Key('schedule_pair_toggle_${pair.pairId}'),
      deleteKey: Key('schedule_pair_delete_${pair.pairId}'),
      onToggle: onToggle,
      onDelete: onDelete,
      onEdit: onEdit,
    );
  }

  static DateTime? _earliest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
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
