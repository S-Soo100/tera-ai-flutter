import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/data/activity_repository.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';
import 'package:vivanaut/features/my_pets/domain/activity_window.dart';
import 'package:vivanaut/features/my_pets/presentation/activity_providers.dart';

class DeferredActivityRepository implements ActivityRepository {
  final requests = <({
    String cameraId,
    ActivityWindow window,
    Completer<ActivityData> result
  })>[];
  @override
  Future<ActivityData> load(
      {required String cameraId, required ActivityWindow window}) {
    final result = Completer<ActivityData>();
    requests.add((cameraId: cameraId, window: window, result: result));
    return result.future;
  }
}

void main() {
  test('late old-pet response cannot replace selected-pet data', () async {
    final repo = DeferredActivityRepository();
    final container = ProviderContainer(overrides: [
      activityRepositoryProvider('user').overrideWith((ref) => repo),
    ]);
    addTearDown(container.dispose);
    final window = ActivityWindow.day(2026, 9, 15);
    final old = ActivityQuery(
        userId: 'user',
        petId: 'old',
        window: window,
        assignments: [
          ActivityAssignment(cameraId: 'a', origin: ActivityOrigin.legacy)
        ]);
    final selected = ActivityQuery(
        userId: 'user',
        petId: 'new',
        window: window,
        assignments: [
          ActivityAssignment(cameraId: 'b', origin: ActivityOrigin.legacy)
        ]);
    final oldFuture = container.read(activityDataProvider(old).future);
    final selectedFuture =
        container.read(activityDataProvider(selected).future);
    repo.requests[1].result
        .complete(const ActivityData(videoClipCount: 2, exactClipCount: 2));
    expect((await selectedFuture).videoClipCount, 2);
    repo.requests[0].result
        .complete(const ActivityData(videoClipCount: 9, exactClipCount: 9));
    await oldFuture;
    expect(
        container
            .read(activityDataProvider(selected))
            .requireValue
            .videoClipCount,
        2);
  });
  test('late former-camera response cannot replace the same pet current camera',
      () async {
    final repo = DeferredActivityRepository();
    final container = ProviderContainer(overrides: [
      activityRepositoryProvider('user').overrideWith((ref) => repo),
    ]);
    addTearDown(container.dispose);
    final day = ActivityWindow.day(2026, 8, 1);
    ActivityQuery query(String cameraId) => ActivityQuery(
        userId: 'user',
        petId: 'same-pet',
        window: day,
        assignments: [ActivityAssignment.currentCamera(cameraId)]);
    final former = container.read(activityDataProvider(query('a')).future);
    final current = container.read(activityDataProvider(query('b')).future);
    expect(repo.requests.map((request) => request.cameraId), ['a', 'b']);
    expect(repo.requests.every((request) => request.window == day), isTrue);
    repo.requests[1].result.complete(const ActivityData(videoClipCount: 2));
    expect((await current).videoClipCount, 2);
    repo.requests[0].result.complete(const ActivityData(videoClipCount: 9));
    await former;
    expect(
        container
            .read(activityDataProvider(query('b')))
            .requireValue
            .videoClipCount,
        2);
  });
  test(
      'requests clip to each real assignment and legacy leaves original window intact',
      () async {
    final repo = DeferredActivityRepository();
    final container = ProviderContainer(overrides: [
      activityRepositoryProvider('user').overrideWith((ref) => repo),
    ]);
    addTearDown(container.dispose);
    final day = ActivityWindow.day(2026, 9, 15);
    final boundary = DateTime.parse('2026-09-15T03:00:00Z');
    final query =
        ActivityQuery(userId: 'user', petId: 'p', window: day, assignments: [
      ActivityAssignment(
          cameraId: 'old', endUtc: boundary, origin: ActivityOrigin.legacy),
      ActivityAssignment(cameraId: 'new', startUtc: boundary),
    ]);
    final result = container.read(activityDataProvider(query).future);
    expect(repo.requests.single.window.startUtc, day.startUtc);
    expect(repo.requests.single.window.endUtc, boundary);
    repo.requests.single.result.complete(const ActivityData());
    await Future<void>.delayed(Duration.zero);
    expect(repo.requests.last.window.startUtc, boundary);
    expect(repo.requests.last.window.endUtc, day.endUtc);
    repo.requests.last.result.complete(const ActivityData());
    await result;
  });
  test('scope keys separate accounts, pets, assignments and KST weeks', () {
    final day = ActivityWindow.day(2026, 9, 15);
    ActivityQuery query(String user, String pet, ActivityWindow window) =>
        ActivityQuery(userId: user, petId: pet, window: window, assignments: [
          ActivityAssignment(cameraId: 'a', origin: ActivityOrigin.legacy)
        ]);
    expect(query('a', 'p', day), query('a', 'p', day));
    expect(query('a', 'p', day), isNot(query('b', 'p', day)));
    expect(query('a', 'p', day), isNot(query('a', 'q', day)));
    expect(query('a', 'p', day), isNot(query('a', 'p', day.shiftDays(1))));
    expect(
        ActivityWindow.weekContaining(ActivityWindow.containing(
                DateTime.parse('2026-09-13T14:59:59Z')))
            .startUtc,
        DateTime.parse('2026-09-06T15:00:00Z'));
    expect(
        ActivityWindow.weekContaining(ActivityWindow.containing(
                DateTime.parse('2026-09-13T15:00:00Z')))
            .startUtc,
        DateTime.parse('2026-09-13T15:00:00Z'));
  });
}
