import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../data/activity_repository.dart';
import '../data/passed_clip_activity_repository.dart';
import '../domain/activity_summary.dart';
import '../domain/activity_window.dart';

/// 활동 시간의 출처 — **하이라이트 규칙 통과 영상의 길이 합**
/// (2026-09-21 사용자 결정, [PassedClipActivityRepository]).
///
/// 카메라 탭 목록과 같은 집합(petcam-api `/highlights`)을 쓰므로 "화면에 보이는
/// 영상"과 "활동 시간"이 같은 것을 센다. 구 `/activity/intervals`(실제 움직인
/// 구간)는 더 쓰지 않는다.
final activityRepositoryProvider =
    Provider.autoDispose.family<ActivityRepository, String>((ref, userId) {
  if (Supabase.instance.client.auth.currentUser?.id != userId) {
    return const _NoActivityRepository();
  }
  final highlights = ref.watch(highlightRepositoryProvider);
  final clips = ref.watch(motionClipRepositoryProvider);
  return PassedClipActivityRepository(
    listRefs: ({required cameraId, since, until, cursor}) =>
        highlights.listPassedPage(
            cameraId: cameraId, since: since, until: until, cursor: cursor),
    hydrate: clips.getByIds,
  );
});

/// 다른 계정의 요청 — 남의 데이터를 채우지 않는다.
class _NoActivityRepository implements ActivityRepository {
  const _NoActivityRepository();
  @override
  Future<ActivityData> load(
          {required String cameraId, required ActivityWindow window}) async =>
      const ActivityData();
}

final activityClockProvider =
    StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
      const Duration(minutes: 1), (_) => DateTime.now().toUtc());
});
// A null date follows today across Korean midnight. A deliberately selected
// historical day stays fixed, even while the app is left open overnight.
typedef ActivitySelectionScope = ({String? userId, String petId});
final activitySelectedDayProvider = StateProvider.autoDispose
    .family<ActivityWindow?, ActivitySelectionScope>((ref, scope) => null);
final activitySelectedWeekProvider = StateProvider.autoDispose
    .family<ActivityWindow?, ActivitySelectionScope>((ref, scope) => null);

@immutable
class ActivityQuery {
  ActivityQuery(
      {required this.userId,
      required this.petId,
      required this.window,
      required List<ActivityAssignment> assignments})
      : assignments = List.unmodifiable(assignments);
  final String userId;
  final String petId;
  final ActivityWindow window;
  final List<ActivityAssignment> assignments;
  @override
  bool operator ==(Object other) =>
      other is ActivityQuery &&
      other.userId == userId &&
      other.petId == petId &&
      other.window == window &&
      listEquals(other.assignments, assignments);
  @override
  int get hashCode =>
      Object.hash(userId, petId, window, Object.hashAll(assignments));
}

/// Family identity isolates concurrent auth/pet/date requests; old futures never
/// write into another selection. Assignment edits also produce a new key.
final activityDataProvider = FutureProvider.autoDispose
    .family<ActivityData, ActivityQuery>((ref, query) async {
  if (query.assignments.isEmpty) return const ActivityData();
  final repository = ref.watch(activityRepositoryProvider(query.userId));
  final intervals = <ActivityInterval>[];
  final coverage = <ActivityCoverage>[];
  var videos = 0;
  var exact = 0;
  var fallback = 0;
  final reasons = <String, int>{};
  for (final assignment in query.assignments) {
    final from = assignment.startUtc != null &&
            assignment.startUtc!.isAfter(query.window.startUtc)
        ? assignment.startUtc!
        : query.window.startUtc;
    final to = assignment.endUtc != null &&
            assignment.endUtc!.isBefore(query.window.endUtc)
        ? assignment.endUtc!
        : query.window.endUtc;
    if (!to.isAfter(from)) continue;
    final data = await repository.load(
        cameraId: assignment.cameraId,
        window: ActivityWindow(startUtc: from, endUtc: to));
    intervals.addAll(data.intervals);
    coverage.addAll(data.coverage);
    videos += data.videoClipCount;
    exact += data.exactClipCount;
    fallback += data.fallbackClipCount;
    for (final reason in data.fallbackReasons.entries) {
      reasons.update(reason.key, (count) => count + reason.value,
          ifAbsent: () => reason.value);
    }
  }
  // 서버가 coverage를 안 주면 연결 기간의 지난 시간을 관측 완료로 가정한다
  // (2026-09-16 사용자 결정, [assumedCoverage] 주석).
  if (coverage.isEmpty) {
    coverage.addAll(assumedCoverage(
        assignments: query.assignments,
        window: query.window,
        now: DateTime.now().toUtc()));
  }
  return ActivityData(
      intervals: List.unmodifiable(intervals),
      coverage: List.unmodifiable(coverage),
      videoClipCount: videos,
      exactClipCount: exact,
      fallbackClipCount: fallback,
      fallbackReasons: Map.unmodifiable(reasons),
      dataStatus: videos == 0
          ? ActivityDataStatus.noVideo
          : fallback == 0
              ? ActivityDataStatus.exact
              : exact == 0
                  ? ActivityDataStatus.legacyEstimate
                  : ActivityDataStatus.mixed);
});
