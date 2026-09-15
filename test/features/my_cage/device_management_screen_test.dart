import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_detail_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/group_editor_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/management_widgets.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets('group delete cancel writes nothing, confirmed fail=$fail',
        (tester) async {
      var writes = 0;
      var refreshes = 0;
      final inventory = ManagementInventory(groups: [
        const ManagementGroup(id: 'g', name: 'Group')
      ], items: [
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.camera, id: 'c'),
            name: 'Camera',
            groupId: 'g')
      ]);
      final repo = RedesignGroupRepository(
          loadRows: (_) async => [],
          rpc: (name, params) async {
            writes++;
            expect(name, 'redesign_delete_group_v1');
            if (fail) {
              throw const ManagementFailure('management_server_unsupported');
            }
            return {'group_id': 'g', 'deleted': true};
          });
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('returned'))),
        GoRoute(
            path: '/edit',
            builder: (_, __) => const GroupEditorScreen(groupId: 'g'))
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            managementInventoryProvider.overrideWith((ref) async => inventory),
            redesignGroupRepositoryProvider.overrideWith((ref) => repo),
            managementMutationCompletedProvider
                .overrideWithValue(() => refreshes++),
          ],
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
      router.push('/edit');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'unsaved');
      await tester.tap(find.byKey(const Key('management_delete_group')));
      await tester.pumpAndSettle();
      expect(find.text('management_delete_group_confirm'), findsOneWidget);
      await tester.tap(find.text('management_cancel'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(refreshes, 0);
      await tester.tap(find.byKey(const Key('management_delete_group')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('management_delete'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(refreshes, fail ? 0 : 1);
      expect(find.text('returned'), fail ? findsNothing : findsOneWidget);
      if (fail) {
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('unsaved'), findsOneWidget);
        expect(find.text('management_server_unsupported'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('group-add CTA is hidden for only single-member groups',
      (tester) async {
    final inventory = ManagementInventory(groups: [
      const ManagementGroup(id: 'g', name: 'saved')
    ], items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'c'),
          name: 'camera',
          groupId: 'g')
    ]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          managementInventoryProvider.overrideWith((ref) async => inventory)
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const DeviceManagementScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('management_add_group')), findsNothing);
    expect(find.text('saved'), findsOneWidget);
  });
  testWidgets(
      'device power stays ON and sends no write even when OFF is tapped',
      (tester) async {
    var calls = 0;
    final inventory = ManagementInventory(groups: [], items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.device, id: 'd'),
          name: 'device',
          isOnline: false)
    ]);
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async {
          calls++;
          return null;
        });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          managementInventoryProvider.overrideWith((ref) async => inventory),
          redesignGroupRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const DeviceDetailScreen(
                kind: ManagementKind.device, itemId: 'd'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('management_power_off')));
    expect(calls, 0);
    expect(find.byKey(const Key('management_power_on')), findsOneWidget);
    expect(find.text('management_offline'), findsNothing);
  });
  testWidgets('canceling a cross-group move keeps the original selected member',
      (tester) async {
    final inventory = ManagementInventory(groups: [
      const ManagementGroup(id: 'g', name: 'Group'),
      const ManagementGroup(id: 'old', name: 'Old')
    ], items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'a'),
          name: 'Original',
          groupId: 'g'),
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'b'),
          name: 'Candidate',
          groupId: 'old')
    ]);
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [], rpc: (_, __) async => null);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          managementInventoryProvider.overrideWith((ref) async => inventory),
          redesignGroupRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const GroupEditorScreen(groupId: 'g'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('management_add_change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candidate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('management_cancel'));
    await tester.pumpAndSettle();
    final rows =
        tester.widgetList<ManagementItemRow>(find.byType(ManagementItemRow));
    expect(
        rows.firstWhere((row) => row.item.name == 'Original').selected, isTrue);
    expect(rows.firstWhere((row) => row.item.name == 'Candidate').selected,
        isFalse);
  });
  for (final groupEditor in [false, true]) {
    for (final save in [false, true]) {
      testWidgets(
          '${groupEditor ? 'group' : 'device'} dirty editor ${save ? 'save' : 'confirmed discard'} pops once',
          (tester) async {
        var writes = 0;
        final inventory = ManagementInventory(groups: [
          const ManagementGroup(id: 'g', name: 'Group')
        ], items: [
          const ManagementItem(
              key: ManagementKey(kind: ManagementKind.device, id: 'd'),
              name: 'Device',
              groupId: 'g')
        ]);
        final repo = RedesignGroupRepository(
            loadRows: (_) async => [],
            rpc: (name, params) async {
              writes++;
              return name == 'redesign_save_group_v1'
                  ? {'group_id': 'g'}
                  : {'id': 'd'};
            });
        final router = GoRouter(routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('home-marker'))),
          GoRoute(
              path: '/edit',
              builder: (_, __) => groupEditor
                  ? const GroupEditorScreen(groupId: 'g')
                  : const DeviceDetailScreen(
                      kind: ManagementKind.device, itemId: 'd')),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              managementInventoryProvider
                  .overrideWith((ref) async => inventory),
              redesignGroupRepositoryProvider.overrideWith((ref) => repo),
              managementMutationCompletedProvider.overrideWithValue(() {}),
            ],
            child: MaterialApp.router(
                theme: AppTheme.light, routerConfig: router)));
        router.push('/edit');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Changed');
        await tester.pumpAndSettle();
        if (save) {
          await tester.tap(find.text('management_done'));
        } else {
          final context = tester.element(find.byType(TextFormField));
          Navigator.of(context).maybePop();
          await tester.pumpAndSettle();
          expect(find.text('management_discard'), findsOneWidget);
          await tester.tap(find.text('management_confirm'));
        }
        await tester.pumpAndSettle();
        expect(find.text('home-marker'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(writes, save ? 1 : 0);
      });
    }
  }
  for (final kind in ManagementKind.values) {
    testWidgets('group member ${kind.name} opens its own detail without saving',
        (tester) async {
      var writes = 0;
      final item = ManagementItem(
          key: ManagementKey(kind: kind, id: 'member'),
          name: 'Member',
          groupId: 'g');
      final inventory = ManagementInventory(
          groups: [const ManagementGroup(id: 'g', name: 'Group')],
          items: [item]);
      final repo = RedesignGroupRepository(
          loadRows: (_) async => [],
          rpc: (_, __) async {
            writes++;
            return null;
          });
      final route = kind == ManagementKind.pet
          ? '/my-pets/member/edit'
          : '/devices/${kind.name}/member';
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const GroupEditorScreen(groupId: 'g')),
        GoRoute(
            path: route,
            builder: (_, __) =>
                const Scaffold(body: Text('member-destination')))
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            managementInventoryProvider.overrideWith((ref) async => inventory),
            redesignGroupRepositoryProvider.overrideWith((ref) => repo)
          ],
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member'));
      await tester.pumpAndSettle();
      expect(find.text('member-destination'), findsOneWidget);
      expect(writes, 0);
    });
  }
  testWidgets('remove from group lives in settings and cancel sends no write',
      (tester) async {
    var writes = 0;
    final inventory = ManagementInventory(groups: [
      const ManagementGroup(id: 'g', name: 'Group')
    ], items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.device, id: 'd'),
          name: 'Device',
          groupId: 'g')
    ]);
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async {
          writes++;
          return null;
        });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const DeviceDetailScreen(
              kind: ManagementKind.device, itemId: 'd'))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      managementInventoryProvider.overrideWith((ref) async => inventory),
      redesignGroupRepositoryProvider.overrideWith((ref) => repo)
    ], child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('management_remove_group'), findsNothing);
    await tester.tap(find.text('management_group_setting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('management_remove_group'));
    await tester.pumpAndSettle();
    expect(find.text('management_remove_confirm'), findsOneWidget);
    await tester.tap(find.text('management_cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Device'), findsWidgets);
  });
}
