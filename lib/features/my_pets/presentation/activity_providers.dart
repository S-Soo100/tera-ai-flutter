import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/env_config.dart';
import '../data/activity_repository.dart';
import '../domain/activity_summary.dart';
import '../domain/activity_window.dart';

final activityRepositoryProvider =
    Provider.autoDispose.family<ActivityRepository, String>((ref, userId) {
  final repo = HttpActivityRepository(
      baseUrl: EnvConfig.backendUrl,
      tokenProvider: () async {
        final auth = Supabase.instance.client.auth;
        if (auth.currentUser?.id != userId) return null;
        return auth.currentSession?.accessToken;
      });
  ref.onDispose(repo.dispose);
  return repo;
});

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
