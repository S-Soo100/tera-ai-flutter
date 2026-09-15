import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_pets/data/activity_repository.dart';
import 'package:vivanaut/features/my_pets/domain/activity_window.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/activity_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_screen.dart';
import 'package:vivanaut/features/my_pets/presentation/pet_assignment_providers.dart';

class TestPets extends StateNotifier<List<Pet>> implements PetListNotifier {
  TestPets(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Requests implements ActivityRepository {
  final calls = <({String id, ActivityWindow window})>[];
  @override
  Future<ActivityData> load(
      {required String cameraId, required ActivityWindow window}) async {
    calls.add((id: cameraId, window: window));
    return const ActivityData();
  }
}

TerraCamera camera(String id, String? group) => TerraCamera(
    id: id,
    cameraId: 'hardware-$id',
    name: id,
    isOnline: false,
    enclosureId: group,
    createdAt: DateTime(2026, 9, 15));

void main() {
  testWidgets(
      'current group camera owns historical queries and replacement, without assignment history',
      (tester) async {
    final source = StateProvider<List<TerraCamera>>(
        (ref) => [camera('other', 'elsewhere'), camera('a', 'group')]);
    final repo = Requests();
    var historyReads = 0;
    final selectedDay = ActivityWindow.day(2026, 8, 1);
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-09-15T00:00:00Z')),
      petListProvider.overrideWith((ref) => TestPets([
            Pet(
                id: 'p',
                name: 'Pet',
                speciesId: 's',
                speciesName: 'Gecko',
                enclosureId: 'group',
                createdAt: DateTime(2026, 9, 15))
          ])),
      enclosuresProvider.overrideWith((ref) async => []),
      camerasProvider.overrideWith((ref) => Stream.value(ref.watch(source))),
      petCameraAssignmentsProvider('p').overrideWith((ref) async {
        historyReads++;
        return [];
      }),
      activityClockProvider
          .overrideWith((ref) => Stream.value(DateTime.utc(2026, 9, 16))),
      activitySelectedDayProvider.overrideWith((ref, scope) => selectedDay),
      activitySelectedWeekProvider.overrideWith(
          (ref, scope) => ActivityWindow.weekContaining(selectedDay)),
      activityRepositoryProvider('u').overrideWith((ref) => repo),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const MyPetsScreen())));
    await tester.pumpAndSettle();
    expect(historyReads, 0);
    expect(repo.calls, isNotEmpty);
    expect(repo.calls.every((call) => call.id == 'a'), isTrue);
    expect(
        repo.calls.any((call) =>
            call.window.startUtc ==
                selectedDay.startUtc.subtract(const Duration(days: 7)) &&
            call.window.endUtc == selectedDay.endUtc),
        isTrue);
    repo.calls.clear();
    container.read(source.notifier).state = [
      camera('a', null),
      camera('b', 'group')
    ];
    await tester.pumpAndSettle();
    expect(repo.calls, isNotEmpty);
    expect(repo.calls.every((call) => call.id == 'b'), isTrue);
    expect(repo.calls.any((call) => call.window.endUtc == selectedDay.endUtc),
        isTrue);
    repo.calls.clear();
    container.read(source.notifier).state = [
      camera('a', null),
      camera('b', null)
    ];
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.byKey(const Key('activity_connect_camera')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
