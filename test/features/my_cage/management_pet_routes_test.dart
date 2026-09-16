import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/group_editor_screen.dart';

/// 2026-09-16 시뮬 실측: 루트 화면에서 셸 안 `/my-pets/...`를 push하면 go_router
/// 페이지 키 중복 단언 → 내비게이터 잠김 → 뒤로가기 전멸. 루트 화면의 개체
/// 진입은 셸 밖 `/pets/:id`(·`/edit`)로 가야 한다.
void main() {
  final inventory = ManagementInventory(groups: [
    const ManagementGroup(id: 'g', name: 'Group')
  ], items: [
    const ManagementItem(
        key: ManagementKey(kind: ManagementKind.pet, id: 'p'),
        name: '크랑이',
        groupId: 'g'),
    const ManagementItem(
        key: ManagementKey(kind: ManagementKind.pet, id: 'solo'), name: '혼자'),
  ]);
  final repo = RedesignGroupRepository(
      loadRows: (_) async => [], rpc: (_, __) async => null);

  Future<GoRouter> pump(WidgetTester tester, Widget screen) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(
          path: '/my-pets/:petId',
          builder: (_, __) => const Scaffold(body: Text('shell-pet')),
          routes: [
            GoRoute(
                path: 'edit',
                builder: (_, __) => const Scaffold(body: Text('shell-edit'))),
          ]),
      GoRoute(
          path: '/pets/:petId',
          builder: (_, __) => const Scaffold(body: Text('root-pet')),
          routes: [
            GoRoute(
                path: 'edit',
                builder: (_, __) => const Scaffold(body: Text('root-edit'))),
          ]),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      managementInventoryProvider.overrideWith((ref) async => inventory),
      redesignGroupRepositoryProvider.overrideWith((ref) => repo),
      managementMutationCompletedProvider.overrideWithValue(() {}),
    ], child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('group editor opens a member pet through the root pet edit route',
      (tester) async {
    await pump(tester, const GroupEditorScreen(groupId: 'g'));
    await tester.tap(find.text('크랑이'));
    await tester.pumpAndSettle();
    expect(find.text('root-edit'), findsOneWidget);
    expect(find.text('shell-edit'), findsNothing);
  });

  testWidgets(
      'device management opens an ungrouped pet through the root pet route',
      (tester) async {
    await pump(tester, const DeviceManagementScreen());
    await tester.tap(find.text('혼자'));
    await tester.pumpAndSettle();
    expect(find.text('root-pet'), findsOneWidget);
    expect(find.text('shell-pet'), findsNothing);
  });
}
