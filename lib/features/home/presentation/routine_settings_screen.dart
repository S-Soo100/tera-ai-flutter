import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/num_format.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../domain/schedule.dart';
import '../domain/schedule_device.dart';
import 'schedule_draft_apply.dart';
import 'schedule_providers.dart';
import 'widgets/schedule_device_badge.dart';
import 'widgets/schedule_editor_sheet.dart';

/// 기기 예약 설정(PRD §4.2.2 일정, Figma 1106:5317 목록 / 1106:7142 빈 목록 /
/// 1107:10246 삭제 모드 / 1107:9697 삭제 확인).
///
/// 목록은 기기 아이콘 한 줄(시작 시각 정렬)이고, 같은 `pair_id`의 on/off는
/// 한 예약으로 다룬다(토글·삭제도 둘 다). 추가는 기기 선택(1106:4955) →
/// 기기별 편집기, 수정은 줄 탭 → 같은 편집기. 휴지통은 다중 선택 삭제 모드.
///
/// 정지형 가드·히터 타이머가 펌웨어 후속이라는 안내 각주는 원본에 없어
/// 화면에서 빼고 `docs/design-audits/2026-09-16-remaining-ui-handoff/
/// RESULTS.md`(P10 결정)로 옮겼다.
class RoutineSettingsScreen extends ConsumerStatefulWidget {
  const RoutineSettingsScreen({super.key});

  static const listKey = Key('routine_schedule_list');
  static const addKey = Key('routine_add_schedule');
  static const deleteModeKey = Key('routine_delete_mode');
  static const deleteSelectedKey = Key('routine_delete_selected');
  static const emptyKey = Key('routine_empty_box');

  @override
  ConsumerState<RoutineSettingsScreen> createState() =>
      _RoutineSettingsScreenState();
}

class _RoutineSettingsScreenState extends ConsumerState<RoutineSettingsScreen> {
  bool _deleteMode = false;

  /// 삭제 모드 선택 — 구간은 `pair:<pairId>`, 시점은 `one:<id>`.
  final Set<String> _selected = {};

  static String _rowId(Object row) => row is SchedulePair
      ? 'pair:${row.pairId}'
      : 'one:${(row as Schedule).id}';

  /// 같은 pair_id의 on/off는 한 줄(2026-08-18 회신 §3), 시작 시각 순.
  static List<Object> _rows(List<Schedule> list) => scheduleRows(list);

  void _exitDeleteMode() => setState(() {
        _deleteMode = false;
        _selected.clear();
      });

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(schedulesProvider);
    final glass = context.glass;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final rows = _rows(schedules.valueOrNull ?? const []);
    final selectedCount =
        rows.where((r) => _selected.contains(_rowId(r))).length;

    return PopScope(
        canPop: !_deleteMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitDeleteMode();
        },
        child: Scaffold(
            backgroundColor: glass.surfaceTint,
            body: Stack(children: [
              SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ManagementTopBar(
                            title: 'routine_screen_title'.tr(),
                            onBack: _deleteMode
                                ? _exitDeleteMode
                                : () => Navigator.of(context).maybePop(),
                            trailing: IconButton(
                                key: RoutineSettingsScreen.deleteModeKey,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                    width: 44, height: 44),
                                tooltip: 'routine_delete_title'.tr(),
                                onPressed: rows.isEmpty
                                    ? null
                                    : () => _deleteMode
                                        ? _exitDeleteMode()
                                        : setState(() => _deleteMode = true),
                                icon: FigmaIcon.tinted(FigmaIcons.trash,
                                    size: 44,
                                    color: rows.isEmpty
                                        ? glass.deviceOff
                                        : glass.textSecondary)))),
                    Expanded(
                        child: schedules.when(
                      loading: () => const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                              padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
                              child: SkeletonListLoading(itemCount: 3))),
                      error: (e, _) => _ErrorNote(message: '$e'),
                      // Expanded는 세로를 꽉 채우라고 하므로 상자는 Align으로
                      // 느슨하게 받아야 64를 지킨다.
                      data: (list) => rows.isEmpty
                          ? const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                  padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
                                  child: _EmptyBox()))
                          : ListView(
                              key: RoutineSettingsScreen.listKey,
                              // 원본 첫 줄 y122 = 헤더 106 + 16. 하단은 플로팅
                              // CTA(56, 세이프 66 위) + 여유 16.
                              padding: EdgeInsets.fromLTRB(
                                  12, 16, 12, bottom + 66 + 56 + 16),
                              children: [
                                for (final (i, row) in rows.indexed) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  _row(row, list),
                                ],
                              ],
                            ),
                    )),
                  ])),
              if (!_deleteMode || selectedCount > 0)
                Positioned(
                    left: 12,
                    right: 12,
                    bottom: bottom + 66,
                    child: _deleteMode
                        ? ManagementButton(
                            key: RoutineSettingsScreen.deleteSelectedKey,
                            red: true,
                            label: 'routine_delete_count'
                                .tr(args: ['$selectedCount']),
                            onPressed: () => _deleteSelected(rows, schedules))
                        : ManagementButton(
                            key: RoutineSettingsScreen.addKey,
                            label: 'routine_add'.tr(),
                            onPressed: _add)),
            ])));
  }

  Widget _row(Object row, List<Schedule> all) {
    final id = _rowId(row);
    final selected = _selected.contains(id);
    void toggleSelect() => setState(() {
          if (!_selected.remove(id)) _selected.add(id);
        });
    if (row case final SchedulePair p) {
      final on = p.on;
      return ScheduleRow(
        key: Key('schedule_pair_${p.pairId}'),
        device: ScheduleDevice.of(on.action),
        title: '${on.hhmm}~${p.off.hhmm}',
        parts: [
          scheduleRepeatLabel(on.kind, on.daysOfWeek),
          scheduleStateLabel(p.enabled),
          if (on.guard case final g? when g.enabled) _guardLabel(g),
          if (p.isSkewed) 'routine_pair_skewed'.tr(),
        ],
        enabled: p.enabled,
        toggleKey: Key('schedule_pair_toggle_${p.pairId}'),
        checkKey: Key('schedule_pair_check_${p.pairId}'),
        deleteMode: _deleteMode,
        selected: selected,
        onToggle: (v) => _guard(
            () => ref.read(schedulesProvider.notifier).setPairEnabled(p, v)),
        onTap: _deleteMode ? toggleSelect : () => _editPair(p),
      );
    }
    final s = row as Schedule;
    final device = ScheduleDevice.of(s.action);
    return ScheduleRow(
      key: Key('schedule_${s.id}'),
      device: device,
      title: scheduleSingleTitle(s, device),
      parts: [
        scheduleRepeatLabel(s.kind, s.daysOfWeek),
        scheduleStateLabel(s.enabled),
        if (s.guard case final g? when g.enabled) _guardLabel(g),
      ],
      enabled: s.enabled,
      toggleKey: Key('schedule_toggle_${s.id}'),
      checkKey: Key('schedule_check_${s.id}'),
      deleteMode: _deleteMode,
      selected: selected,
      onToggle: (v) =>
          _guard(() => ref.read(schedulesProvider.notifier).setEnabled(s, v)),
      onTap: _deleteMode ? toggleSelect : () => _edit(s, all),
    );
  }

  // ── 추가 ────────────────────────────────────────────────────────────────

  Future<void> _add() async {
    final result = await Navigator.of(context).push<Object>(MaterialPageRoute(
        builder: (_) => ScheduleDevicePickerScreen(
            onPick: (ctx, device) => showScheduleEditor(ctx, device: device))));
    if (result is! ScheduleDraft || !mounted) return;
    await _guard(() => applyScheduleDraft(ref, result));
  }

  // ── 수정 ────────────────────────────────────────────────────────────────

  Future<void> _edit(Schedule s, List<Schedule> all) async {
    // `action`은 서버가 수정을 안 받는다. 편집기는 타이밍만 바꾸고 가드는
    // 손대지 않는다(PATCH에 guard 키 생략 → 서버 값 유지).
    final result = await showScheduleEditor(context, initial: s);
    if (!mounted) return;
    switch (result) {
      case ScheduleDraft():
        await _guard(() => applyScheduleDraft(ref, result, editing: s));
      case ScheduleDeleteRequested():
        if (!await _confirmDelete(_leavesOrphanOn([s], all))) return;
        await _guard(() => ref.read(schedulesProvider.notifier).remove(s));
      case null:
        return;
    }
  }

  Future<void> _editPair(SchedulePair p) async {
    final result = await showScheduleEditor(context, initialPair: p);
    if (!mounted) return;
    switch (result) {
      case ScheduleDraft():
        await _guard(() => applyScheduleDraft(ref, result, editingPair: p));
      case ScheduleDeleteRequested():
        if (!await _confirmDelete(false)) return;
        await _guard(() => ref.read(schedulesProvider.notifier).removePair(p));
      case null:
        return;
    }
  }

  // ── 삭제 ────────────────────────────────────────────────────────────────

  /// 끄기 예약을 지우는데 짝이 될 켜기 예약이 살아 있으면 경고를 바꾼다 —
  /// pair_id 없는 낱개(2026-08-18 이전 구간, 웹 콘솔 생성)는 이 목록 검사로만
  /// 잡을 수 있다. 켜기만 남으면 기기가 켜진 채 방치된다(히터면 과열).
  static bool _leavesOrphanOn(List<Schedule> deleting, List<Schedule> all) {
    final deletingIds = deleting.map((e) => e.id).toSet();
    return deleting.any((s) =>
        s.action.isOffAction &&
        all.any((e) =>
            !deletingIds.contains(e.id) &&
            e.enabled &&
            e.action == s.action.onCounterpart));
  }

  Future<void> _deleteSelected(
      List<Object> rows, AsyncValue<List<Schedule>> schedules) async {
    final targets = rows.where((r) => _selected.contains(_rowId(r))).toList();
    if (targets.isEmpty) return;
    final all = schedules.valueOrNull ?? const <Schedule>[];
    final singles = targets.whereType<Schedule>().toList();
    if (!await _confirmDelete(_leavesOrphanOn(singles, all))) return;
    if (!mounted) return;
    final notifier = ref.read(schedulesProvider.notifier);
    var failed = false;
    for (final t in targets) {
      try {
        if (t is SchedulePair) {
          await notifier.removePair(t);
        } else {
          await notifier.remove(t as Schedule);
        }
        _selected.remove(_rowId(t));
      } catch (e) {
        failed = true;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('routine_action_failed'.tr(args: ['$e']))),
        );
        break;
      }
    }
    if (!mounted) return;
    // 일부 실패면 남은 항목을 서버에서 다시 읽는다 — 성공한 것을 다시 지우지
    // 않고, 지워졌다고 믿지도 않는다.
    if (failed) ref.invalidate(schedulesProvider);
    _exitDeleteMode();
  }

  /// Figma 1107:9697 — 345×144, 문구 18/500/28 가운데, 취소(검정)·삭제(빨강)
  /// 142×44 r8 사이 13. 끄기 예약의 켜기 짝이 남으면 문구를 경고로 바꾼다.
  Future<bool> _confirmDelete(bool leavesOrphanOn) async {
    final ok = await showDialog<bool>(
        context: context,
        useSafeArea: false,
        builder: (ctx) => Dialog(
            backgroundColor: ctx.glass.surfaceHeader,
            surfaceTintColor: ctx.glass.surfaceHeader,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 345),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          (leavesOrphanOn
                                  ? 'routine_delete_off_warning'
                                  : 'routine_delete_question')
                              .tr(),
                          key: leavesOrphanOn
                              ? const Key('routine_delete_off_warning')
                              : const Key('routine_delete_question'),
                          textAlign: TextAlign.center,
                          style: managementStyle(ctx,
                                  size: 18, color: ctx.glass.textPrimary)
                              .copyWith(height: 28 / 18)),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(
                            child: _ModalButton(
                                key: const Key('routine_delete_cancel'),
                                label: 'common_cancel'.tr(),
                                color: ctx.glass.textPrimary,
                                onPressed: () => Navigator.pop(ctx, false))),
                        const SizedBox(width: 13),
                        Expanded(
                            child: _ModalButton(
                                key: const Key('routine_delete_ok'),
                                label: 'routine_delete_confirm'.tr(),
                                color: ctx.glass.navSelected,
                                onPressed: () => Navigator.pop(ctx, true))),
                      ]),
                    ])))));
    return ok == true && mounted;
  }

  /// 실패를 삼키지 않는다. 예약은 "됐겠지"로 넘길 수 있는 동작이 아니다 —
  /// 사용자는 기기가 알아서 돌 거라 믿고 신경을 끈다.
  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('routine_action_failed'.tr(args: ['$e']))),
      );
    }
  }
}

// ── 부제 조각 헬퍼 (시점·구간 공용) ─────────────────────────────────────────

/// 같은 pair_id의 on/off는 한 줄(2026-08-18 회신 §3), 시작 시각 순 — 디자이너
/// 메모 "예약 목록 정렬: 시작 시각". 홈 제어 시트의 예약 탭도 같은 순서다.
List<Object> scheduleRows(List<Schedule> list) {
  int start(Object row) {
    final s = row is SchedulePair ? row.on : row as Schedule;
    return s.hour * 60 + s.minute;
  }

  return Schedule.group(list)..sort((a, b) => start(a) - start(b));
}

/// 매일 또는 `토 일`(원본 1106:5317 — 요일 사이 공백).
String scheduleRepeatLabel(ScheduleKind kind, List<int> daysOfWeek) {
  if (kind == ScheduleKind.daily) return 'routine_daily'.tr();
  return ([...daysOfWeek]..sort()).map((d) => 'routine_day_$d'.tr()).join(' ');
}

/// 분무는 시각 + 분사 시간("12:00 5초" — 2026-09-23 5/10초 선택 도입으로
/// 원본 1106:5317의 시각만 문법에 초를 붙였다. 옛 1/2/3초 예약도 저장값 그대로
/// 보인다), 냉각팬 duration 예약(fan2_on + duration_ms)은 "12:00~12:30", 그 외
/// 켜기/끄기·레거시 동작은 시각 뒤에 동작 이름을 붙여야 같은 아이콘의
/// 켜기·끄기가 구분된다.
String scheduleSingleTitle(Schedule s, ScheduleDevice? device) {
  final ms = s.payload?['duration_ms'];
  if (device == ScheduleDevice.mist) {
    if (ms is! num || ms <= 0) return s.hhmm;
    return '${s.hhmm} ${'home_mist_seconds'.tr(args: ['${ms ~/ 1000}'])}';
  }
  if (s.action == ScheduleAction.fan2On && ms is num && ms > 0) {
    final end = (s.hour * 60 + s.minute + ms ~/ 60000) % (24 * 60);
    final hh = (end ~/ 60).toString().padLeft(2, '0');
    final mm = (end % 60).toString().padLeft(2, '0');
    return '${s.hhmm}~$hh:$mm';
  }
  return '${s.hhmm} ${s.action.displayKey.tr()}';
}

String scheduleStateLabel(bool enabled) =>
    (enabled ? 'device_state_on' : 'device_state_off').tr();

/// `습도>70%면 건너뜀` 식. 키는 `routine_guard_chip_<wire 뒷부분>`.
String _guardLabel(ScheduleGuard g) {
  final key =
      'routine_guard_chip_${g.type.wire.substring('skip_when_'.length)}';
  return key.tr(args: [formatCompact(g.value, maxFractionDigits: 2)]);
}

/// 예약 한 줄 — 369×72 #FAFAFA r12, 아이콘 40, 제목 16/600·부제 14/500,
/// 스위치 80×32. 삭제 모드면 스위치가 왼쪽으로 밀리고 체크 24가 붙는다
/// (1107:10246 — 스위치 x285→253, 체크 x341).
class ScheduleRow extends StatelessWidget {
  const ScheduleRow({
    required super.key,
    required this.device,
    required this.title,
    required this.parts,
    required this.enabled,
    required this.toggleKey,
    required this.checkKey,
    required this.deleteMode,
    required this.selected,
    required this.onToggle,
    required this.onTap,
  });

  final ScheduleDevice? device;
  final String title;
  final List<String> parts;
  final bool enabled;
  final Key toggleKey;
  final Key checkKey;
  final bool deleteMode;
  final bool selected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Material(
        color: ManagementColors.buttonForeground(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
                height: 72,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      ScheduleDeviceBadge(device),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context,
                                    weight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(parts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context, size: 14)),
                          ])),
                      const SizedBox(width: 8),
                      ScheduleSwitch(
                          key: toggleKey,
                          value: enabled,
                          color: scheduleDeviceColor(context, device) ??
                              glass.textPrimary,
                          onChanged: onToggle),
                      if (deleteMode) ...[
                        const SizedBox(width: 8),
                        FigmaIcon.tinted(
                            selected
                                ? 'redesign_v2/check_box_400'
                                : 'redesign_v2/check_box_outline_blank_400',
                            key: checkKey,
                            size: 24,
                            color:
                                selected ? glass.navSelected : glass.deviceOff),
                      ],
                    ])))));
  }
}

/// 원본 Toggle_on/off(1106:5317) — 80×32 r16, 손잡이 50×28 #F4F4F4 여백 2.
/// 켜짐은 기기색, 꺼짐은 [GlassPalette.deviceOff].
class ScheduleSwitch extends StatelessWidget {
  const ScheduleSwitch(
      {super.key,
      required this.value,
      required this.color,
      required this.onChanged});

  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Semantics(
        toggled: value,
        button: true,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 80,
                height: 32,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: value ? color : glass.deviceOff,
                    borderRadius: BorderRadius.circular(16)),
                child: AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                        width: 50,
                        height: 28,
                        decoration: BoxDecoration(
                            color: glass.surfaceTint,
                            borderRadius: BorderRadius.circular(14)))))));
  }
}

class _ModalButton extends StatelessWidget {
  const _ModalButton(
      {super.key,
      required this.label,
      required this.color,
      required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 44,
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: ManagementColors.buttonForeground(context),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: managementStyle(context, weight: FontWeight.w600)
                  .copyWith(height: 28 / 16)),
          child: Text(label)));
}

/// 빈 목록 — 원본 1106:7142 흰 상자 369×64 r12, 문구 16/500/28 #949090.
class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) => Container(
      key: RoutineSettingsScreen.emptyKey,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          color: context.glass.surfaceHeader,
          borderRadius: BorderRadius.circular(12)),
      child: Text('routine_schedule_empty'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: managementStyle(context, color: context.glass.textTertiary)
              .copyWith(height: 28 / 16)));
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'routine_load_failed'.tr(args: [message]),
        style:
            theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}
