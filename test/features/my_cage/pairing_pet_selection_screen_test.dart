import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/pairing_pet_selection_screen.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';

void main() {
  final now = DateTime(2026, 9, 15);
  Pet pet(String id, String name, {String? groupId}) => Pet(
      id: id,
      name: name,
      speciesId: 'leo',
      speciesName: '레오파드 게코',
      enclosureId: groupId,
      createdAt: now,
      updatedAt: now);

  ManagementInventory inventory(
          {String? selectedPet = 'one',
          bool includeCandidate = false,
          String? candidateGroup}) =>
      ManagementInventory(groups: const [
        ManagementGroup(id: 'target', name: '사육 환경 1'),
        ManagementGroup(id: 'other', name: '사육 환경 2'),
      ], items: [
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.device, id: 'device'),
            name: '온습도계',
            groupId: 'target'),
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.camera, id: 'camera'),
            name: '카메라',
            groupId: 'target'),
        if (selectedPet != null)
          ManagementItem(
              key: ManagementKey(kind: ManagementKind.pet, id: selectedPet),
              name: selectedPet == 'one' ? '첫째' : '둘째',
              groupId: 'target'),
        if (includeCandidate)
          ManagementItem(
              key: const ManagementKey(kind: ManagementKind.pet, id: 'two'),
              name: '둘째',
              groupId: candidateGroup),
      ]);

  Future<void> pumpScreen(WidgetTester tester,
      {required ManagementInventory value,
      required List<Pet> pets,
      required RedesignGroupRepository repo,
      required GoRouter router,
      VoidCallback? refresh}) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      managementInventoryProvider.overrideWith((ref) async => value),
      redesignGroupRepositoryProvider.overrideWith((ref) => repo),
      pairingPetsProvider.overrideWith((ref) => pets),
      managementMutationCompletedProvider.overrideWithValue(refresh ?? () {}),
    ], child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    router.go('/groups/target/choose-pet');
    await tester.pumpAndSettle();
  }

  testWidgets(
      'selecting a pet replaces only the group pet and preserves devices',
      (tester) async {
    Map<String, Object?>? params;
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, value) async {
          params = value;
          return {'group_id': 'target'};
        });
    final router = GoRouter(routes: [
      GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
      GoRoute(
          path: '/groups/:groupId/choose-pet',
          builder: (_, state) => PairingPetSelectionScreen(
              groupId: state.pathParameters['groupId']!)),
    ]);
    addTearDown(router.dispose);
    await pumpScreen(tester,
        value: inventory(includeCandidate: true),
        pets: [pet('one', '첫째', groupId: 'target'), pet('two', '둘째')],
        repo: repo,
        router: router);

    await tester.tap(find.text('둘째'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pairing_pet_save')));
    await tester.pumpAndSettle();

    expect(params?['p_pet_id'], 'two');
    expect(params?['p_device_id'], 'device');
    expect(params?['p_camera_id'], 'camera');
    expect(
        params?['p_expected_members'],
        containsAll([
          {'kind': 'pet', 'id': 'one', 'group_id': 'target'},
          {'kind': 'pet', 'id': 'two', 'group_id': null},
        ]));
  });

  testWidgets('canceling a cross-group move retains the current pet',
      (tester) async {
    var writes = 0;
    final router = GoRouter(routes: [
      GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
      GoRoute(
          path: '/groups/:groupId/choose-pet',
          builder: (_, state) => PairingPetSelectionScreen(
              groupId: state.pathParameters['groupId']!)),
    ]);
    addTearDown(router.dispose);
    await pumpScreen(tester,
        value: inventory(includeCandidate: true, candidateGroup: 'other'),
        pets: [
          pet('one', '첫째', groupId: 'target'),
          pet('two', '둘째', groupId: 'other')
        ],
        repo: RedesignGroupRepository(
            loadRows: (_) async => [],
            rpc: (_, __) async {
              writes++;
              return {'group_id': 'target'};
            }),
        router: router);

    await tester.tap(find.text('둘째'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('management_cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pairing_pet_save')));
    await tester.pumpAndSettle();
    expect(writes, 1);
  });

  testWidgets('save failure keeps the chosen pet on screen', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
      GoRoute(
          path: '/groups/:groupId/choose-pet',
          builder: (_, state) => PairingPetSelectionScreen(
              groupId: state.pathParameters['groupId']!)),
    ]);
    addTearDown(router.dispose);
    await pumpScreen(tester,
        value: inventory(includeCandidate: true),
        pets: [pet('one', '첫째', groupId: 'target'), pet('two', '둘째')],
        repo: RedesignGroupRepository(
            loadRows: (_) async => [],
            rpc: (_, __) async =>
                throw const ManagementFailure('management_save_failed')),
        router: router);
    await tester.tap(find.text('둘째'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pairing_pet_save')));
    await tester.pumpAndSettle();
    expect(find.text('둘째'), findsOneWidget);
    expect(find.text('management_save_failed'), findsOneWidget);
  });

  testWidgets('later returns home without a write', (tester) async {
    var writes = 0;
    final router = GoRouter(routes: [
      GoRoute(path: '/home', builder: (_, __) => const Text('home')),
      GoRoute(
          path: '/groups/:groupId/choose-pet',
          builder: (_, state) => PairingPetSelectionScreen(
              groupId: state.pathParameters['groupId']!)),
    ]);
    addTearDown(router.dispose);
    await pumpScreen(tester,
        value: inventory(),
        pets: [pet('one', '첫째', groupId: 'target')],
        repo: RedesignGroupRepository(
            loadRows: (_) async => [],
            rpc: (_, __) async {
              writes++;
              return {'group_id': 'target'};
            }),
        router: router);
    await tester.tap(find.byKey(const Key('pairing_pet_later')));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('home'), findsOneWidget);
  });
}
