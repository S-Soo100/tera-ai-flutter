import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../my_cage/domain/motion_clip.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../domain/day_window.dart';
import '../domain/timeline_summary.dart';
import 'home_set_providers.dart';

/// 타임라인이 보고 있는 날짜(창의 시작 날짜). 기본은 오늘.
final timelineDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DayWindow.of(DateTime.now()).labelDate;
});

/// 선택된 이벤트 필터.
final timelineFilterProvider =
    StateProvider.autoDispose<TimelineFilter>((ref) => TimelineFilter.all);

/// 선택 날짜 창(07:00~익일 07:00)의 모션 클립.
final timelineClipsProvider =
    FutureProvider.autoDispose<List<MotionClip>>((ref) async {
  final date = ref.watch(timelineDateProvider);
  final set = await ref.watch(currentSetProvider.future);
  final cameraId = set?.camera?.id;
  if (cameraId == null) return const [];
  final w = DayWindow.forDate(date);
  return ref
      .watch(motionClipRepositoryProvider)
      .listByCameraInWindow(cameraId, from: w.start, to: w.end);
});

/// 당일 요약.
final timelineSummaryProvider =
    FutureProvider.autoDispose<TimelineSummary>((ref) async {
  final clips = await ref.watch(timelineClipsProvider.future);
  return TimelineSummary.from(
    clips: clips,
    window: const Duration(hours: 24),
  );
});

/// 필터별 건수 — 0인 필터의 칩은 Disabled.
final timelineFilterCountsProvider =
    FutureProvider.autoDispose<Map<TimelineFilter, int>>((ref) async {
  return countByFilter(await ref.watch(timelineClipsProvider.future));
});

/// 필터가 적용된 클립 목록.
final filteredTimelineClipsProvider =
    FutureProvider.autoDispose<List<MotionClip>>((ref) async {
  final filter = ref.watch(timelineFilterProvider);
  final clips = await ref.watch(timelineClipsProvider.future);
  switch (filter) {
    case TimelineFilter.all:
    case TimelineFilter.moving:
      return clips;
    case TimelineFilter.eating:
      return clips
          .where((c) => TimelineSummary.eatActions.contains(c.action))
          .toList();
    case TimelineFilter.drinking:
      return clips.where((c) => c.action == 'drinking').toList();
    case TimelineFilter.shedding:
      return clips.where((c) => c.action == 'shedding').toList();
  }
});
