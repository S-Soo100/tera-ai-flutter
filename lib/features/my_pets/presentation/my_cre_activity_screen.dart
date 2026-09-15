import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../data/activity_repository.dart';
import '../domain/activity_summary.dart';
import '../domain/activity_window.dart';
import '../domain/pet.dart';
import 'activity_providers.dart';
import 'widgets/activity_day_chart.dart';
import 'widgets/activity_pet_header.dart';
import 'widgets/activity_week_chart.dart';

/// Parent owns group selection and routes. Header is fixed; the profile always
/// displays the individual's name, never the group's display name.
class MyCreActivityScreen extends ConsumerWidget {
  const MyCreActivityScreen(
      {super.key,
      required this.header,
      required this.pet,
      required this.userId,
      required this.hasCameraConnection,
      required this.assignments,
      required this.onAddPet,
      required this.onOpenLegacyReports,
      this.assignmentNotice,
      this.onEditPet,
      this.onConnectCamera});
  final Widget header;
  final Pet? pet;
  final String? userId;
  final bool? hasCameraConnection;
  final VoidCallback? onConnectCamera;
  final List<ActivityAssignment> assignments;
  final VoidCallback onAddPet;
  final VoidCallback onOpenLegacyReports;
  final VoidCallback? onEditPet;
  final Widget? assignmentNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = pet;
    final legacy = TextButton(
        key: const Key('activity_legacy'),
        onPressed: onOpenLegacyReports,
        child: Text('activity_legacy_reports'.tr()));
    if (selected == null) {
      return Scaffold(
          body: SafeArea(
              bottom: false,
              child: Column(children: [
                header,
                Expanded(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 144, 24, 100),
                        child: Column(children: [
                          const Image(image: FigmaImages.emptyPet),
                          const SizedBox(height: 16),
                          Text('activity_empty'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontSize: 16,
                                      height: 1.193359375,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -.32,
                                      color: context.glass.bodySecondary)),
                          const SizedBox(height: 16),
                          SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton(
                                  key: const Key('activity_add_pet'),
                                  onPressed: onAddPet,
                                  style: FilledButton.styleFrom(
                                      backgroundColor:
                                          context.glass.textPrimary,
                                      foregroundColor:
                                          context.glass.surfaceHeader,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  child: Text('activity_add_pet'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -.36,
                                              color: context
                                                  .glass.surfaceHeader)))),
                          legacy
                        ]))),
              ])));
    }
    final scope = (userId: userId, petId: selected.id);
    final now =
        ref.watch(activityClockProvider).valueOrNull ?? DateTime.now().toUtc();
    final today = ActivityWindow.containing(now);
    final day = ref.watch(activitySelectedDayProvider(scope)) ?? today;
    final week = ref.watch(activitySelectedWeekProvider(scope)) ??
        ActivityWindow.weekContaining(today);
    final dayRange = ActivityWindow(
        startUtc: day.startUtc.subtract(const Duration(days: 7)),
        endUtc: day.endUtc);
    final dayQuery = ActivityQuery(
        userId: userId ?? '',
        petId: selected.id,
        window: dayRange,
        assignments: assignments);
    final weekQuery = ActivityQuery(
        userId: userId ?? '',
        petId: selected.id,
        window: week,
        assignments: assignments);
    final unlinked = hasCameraConnection == false;
    final canQuery = !unlinked && userId != null && assignments.isNotEmpty;
    final dayAsync = canQuery
        ? ref.watch(activityDataProvider(dayQuery))
        : const AsyncData(ActivityData());
    final weekAsync = canQuery
        ? ref.watch(activityDataProvider(weekQuery))
        : const AsyncData(ActivityData());
    final dayData = dayAsync.asData?.value ?? const ActivityData();
    final weekData = weekAsync.asData?.value ?? const ActivityData();
    ActivityDaySummary summarize(ActivityWindow range, ActivityData data) =>
        aggregateActivityDay(
            window: range,
            intervals: data.intervals,
            assignments: assignments,
            coverage: data.coverage,
            now: now);
    final daily = summarize(day, dayData);
    final average = previousActivityAverage(day,
        [for (var i = 1; i <= 7; i++) summarize(day.shiftDays(-i), dayData)]);
    final weekly = ActivityWeekSummary(window: week, days: [
      for (var i = 0; i < 7; i++)
        summarize(
            ActivityWindow(
                startUtc: week.startUtc.add(Duration(days: i)),
                endUtc: week.startUtc.add(Duration(days: i + 1))),
            weekData)
    ]);
    return Scaffold(
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              header,
              Expanded(
                  child: SingleChildScrollView(
                      key: PageStorageKey('activity-$userId-${selected.id}'),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ActivityPetHeader(pet: selected, onEdit: onEditPet),
                            if (assignmentNotice != null) assignmentNotice!,
                            if (unlinked)
                              Padding(
                                  padding: const EdgeInsets.only(
                                      top: 20, bottom: 20),
                                  child: Column(children: [
                                    Text('activity_connect_camera_hint'.tr(),
                                        key:
                                            const Key('activity_no_connection'),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontSize: 16,
                                                height: 1.193359375,
                                                letterSpacing: -.32,
                                                fontWeight: FontWeight.w500,
                                                color: context
                                                    .glass.bodySecondary)),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                        height: 56,
                                        child: FilledButton(
                                            key: const Key(
                                                'activity_connect_camera'),
                                            onPressed: onConnectCamera,
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    context.glass.navSelected,
                                                foregroundColor: context
                                                    .glass.buttonForeground,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            28))),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  FigmaIcon.tinted(
                                                      FigmaIcons.add,
                                                      size: 24,
                                                      color: context.glass
                                                          .buttonForeground),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                      'activity_connect_camera'
                                                          .tr(),
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          height: 28 / 18,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          letterSpacing: -.36)),
                                                ]))),
                                  ])),
                            const SizedBox(height: 20),
                            _DateRow(
                                label: DateFormat('yyyy. M. d')
                                    .format(day.kstDate),
                                onPrevious: () => ref
                                    .read(activitySelectedDayProvider(scope)
                                        .notifier)
                                    .state = day.shiftDays(-1),
                                onNext: day.startUtc.isBefore(today.startUtc)
                                    ? () => ref
                                        .read(activitySelectedDayProvider(scope)
                                            .notifier)
                                        .state = day.shiftDays(1)
                                    : null,
                                onSelect: () => _pickDate(
                                    context, ref, scope, day, today, false)),
                            const SizedBox(height: 12),
                            _Summary(
                                total: unlinked ? 0 : daily.seconds,
                                average: unlinked ? 0 : average.seconds,
                                weekly: false),
                            const SizedBox(height: 12),
                            if (dayAsync.isLoading)
                              const SkeletonCard(height: 256, lineCount: 3)
                            else
                              ActivityDayChart(
                                  key: const Key('activity_day_chart'),
                                  hours: unlinked ? const [] : daily.hours),
                            if (!unlinked)
                              _DataStatus(
                                  async: dayAsync,
                                  estimated: daily.isEstimated,
                                  beforeConnection: daily.state ==
                                      ActivityObservation.beforeConnection,
                                  inProgress: daily.state ==
                                      ActivityObservation.inProgress,
                                  onRetry: () => ref.invalidate(
                                      activityDataProvider(dayQuery))),
                            const SizedBox(height: 40),
                            _DateRow(
                                label:
                                    '${DateFormat('yyyy. M. d').format(week.kstDate)} - '
                                    '${DateFormat('M. d').format(week.kstDate.add(const Duration(days: 6)))}',
                                onPrevious: () =>
                                    ref.read(activitySelectedWeekProvider(scope).notifier).state =
                                        week.shiftDays(-7),
                                onNext: week.startUtc.isBefore(
                                        ActivityWindow.weekContaining(today)
                                            .startUtc)
                                    ? () => ref
                                        .read(
                                            activitySelectedWeekProvider(scope)
                                                .notifier)
                                        .state = week.shiftDays(7)
                                    : null,
                                onSelect: () =>
                                    _pickDate(context, ref, scope, week, today, true)),
                            const SizedBox(height: 12),
                            _Summary(
                                total: unlinked ? 0 : weekly.seconds,
                                average: unlinked ? 0 : weekly.average.seconds,
                                weekly: true),
                            const SizedBox(height: 12),
                            if (weekAsync.isLoading)
                              const SkeletonCard(height: 256, lineCount: 3)
                            else
                              ActivityWeekChart(
                                  key: const Key('activity_week_chart'),
                                  days: unlinked ? const [] : weekly.days),
                            if (!unlinked)
                              _DataStatus(
                                  async: weekAsync,
                                  estimated: weekly.isEstimated,
                                  inProgress: week.endUtc.isAfter(now),
                                  onRetry: () => ref.invalidate(
                                      activityDataProvider(weekQuery))),
                            const SizedBox(height: 20),
                            if (!unlinked)
                              Text('activity_camera_attribution'.tr(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: context.glass.bodySecondary)),
                            legacy,
                          ]))),
            ])));
  }

  Future<void> _pickDate(
      BuildContext context,
      WidgetRef ref,
      ActivitySelectionScope scope,
      ActivityWindow selected,
      ActivityWindow today,
      bool weekly) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: selected.kstDate,
        firstDate: DateTime(1970),
        lastDate: today.kstDate);
    if (picked == null || !context.mounted) return;
    // Selection could change while the dialog is up; don't update an old scope.
    final current = context.widget;
    if (current is! MyCreActivityScreen ||
        current.userId != scope.userId ||
        current.pet?.id != scope.petId) {
      return;
    }
    final day = ActivityWindow.day(picked.year, picked.month, picked.day);
    if (weekly) {
      ref.read(activitySelectedWeekProvider(scope).notifier).state =
          ActivityWindow.weekContaining(day);
    } else {
      ref.read(activitySelectedDayProvider(scope).notifier).state = day;
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow(
      {required this.label,
      required this.onPrevious,
      required this.onNext,
      required this.onSelect});
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 40,
      child: Row(children: [
        IconButton(
            tooltip: 'activity_previous'.tr(),
            onPressed: onPrevious,
            icon: FigmaIcon.tinted(FigmaIcons.arrowPrevious,
                size: 24, color: context.glass.textSecondary)),
        Expanded(
            child: TextButton(
                onPressed: onSelect,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.36,
                        color: context.glass.textSecondary)))),
        IconButton(
            tooltip: 'activity_next'.tr(),
            onPressed: onNext,
            icon: FigmaIcon.tinted(FigmaIcons.arrowNext,
                size: 24,
                color: onNext == null
                    ? context.glass.textTertiary
                    : context.glass.textSecondary)),
      ]));
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.total, required this.average, required this.weekly});
  final double? total;
  final double? average;
  final bool weekly;
  @override
  Widget build(BuildContext context) {
    Widget value(double? seconds, String label, Color color) => Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(activityDuration(seconds),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.56,
                  height: 1.2,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.28,
                  color: context.glass.textTertiary)),
        ]));
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          value(total, 'activity_total'.tr(), context.glass.navSelected),
          const SizedBox(width: 12),
          value(
              average,
              (weekly ? 'activity_week_average' : 'activity_day_average').tr(),
              context.glass.textTertiary),
        ]));
  }
}

class _DataStatus extends StatelessWidget {
  const _DataStatus(
      {required this.async,
      required this.estimated,
      required this.onRetry,
      this.beforeConnection = false,
      this.inProgress = false});
  final AsyncValue<ActivityData> async;
  final bool estimated;
  final bool beforeConnection;
  final bool inProgress;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (async.hasError) {
      return TextButton(onPressed: onRetry, child: Text('activity_retry'.tr()));
    }
    if (async.isLoading) return const SizedBox.shrink();
    final key = beforeConnection
        ? 'activity_before_connection'
        : estimated
            ? 'activity_estimated_notice'
            : inProgress
                ? 'activity_in_progress'
                : null;
    if (key == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(key.tr(),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.glass.bodySecondary)));
  }
}
