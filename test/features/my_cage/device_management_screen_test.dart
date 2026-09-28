import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/data/device_wifi_name_store.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
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
          ? '/pets/member/edit' // 루트 화면은 셸 밖 개체 경로(2026-09-16)
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

  // 기기 상세 [Wi-Fi 바꾸기](2026-09-28) — 지우고 다시 등록하면 새 기기가 된다.
  for (final kind in [ManagementKind.device, ManagementKind.camera]) {
    testWidgets('${kind.name} 상세의 Wi-Fi 바꾸기는 그 기기를 대상으로 연다', (tester) async {
      final inventory = ManagementInventory(groups: [], items: [
        ManagementItem(
            key: ManagementKey(kind: kind, id: 'row'),
            name: '기기 3',
            isOnline: false)
      ]);
      Object? pushed;
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => DeviceDetailScreen(kind: kind, itemId: 'row')),
        GoRoute(
            path: '/devices/wifi',
            builder: (_, state) {
              pushed = state.extra;
              return const SizedBox();
            }),
      ]);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            managementInventoryProvider.overrideWith((ref) async => inventory),
            redesignGroupRepositoryProvider.overrideWith((ref) =>
                RedesignGroupRepository(
                    loadRows: (_) async => [], rpc: (_, __) async => null)),
            deviceAddAccountProvider.overrideWithValue('a'),
            deviceWifiNameStoreProvider.overrideWithValue(
                _WifiNames({('a', PairTargetKind.device, 'row'): 'home_2.4G'})),
          ],
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('device_wifi_change'));
      if (kind == ManagementKind.device && !kWifiChangeDeviceEnabled) {
        expect(button, findsNothing);
        return;
      }
      // 오른쪽은 이 폰이 마지막에 붙인 Wi-Fi 이름, 모르면 '--'.
      final name =
          tester.widget<Text>(find.byKey(const Key('device_wifi_name')));
      expect(name.data, kind == ManagementKind.device ? 'home_2.4G' : '--');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final target = pushed! as WifiChangeTarget;
      expect(target.id, 'row');
      expect(target.name, '기기 3');
      expect(
          target.kind,
          kind == ManagementKind.device
              ? PairTargetKind.device
              : PairTargetKind.camera);
    });
  }

  Future<void> pumpDetail(WidgetTester tester, ManagementItem item) async {
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          managementInventoryProvider.overrideWith(
              (ref) async => ManagementInventory(groups: [], items: [item])),
          redesignGroupRepositoryProvider.overrideWith((ref) =>
              RedesignGroupRepository(
                  loadRows: (_) async => [], rpc: (_, __) async => null)),
          deviceAddAccountProvider.overrideWithValue('a'),
          deviceWifiNameStoreProvider.overrideWithValue(
              _WifiNames({('a', PairTargetKind.camera, 'row'): 'local_ssid'})),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: DeviceDetailScreen(kind: item.key.kind, itemId: 'row'))));
    await tester.pumpAndSettle();
  }

  // 리뷰(2026-09-28): 이 폰이 붙인 이름은 다른 폰에서 바꾸면 옛 이름이 된다 —
  // 기기가 보고한 이름(서버 wifi_ssid)이 오면 그 값이 우선이다.
  testWidgets('서버가 보고한 Wi-Fi 이름이 이 폰의 기억보다 우선이다', (tester) async {
    await pumpDetail(
        tester,
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.camera, id: 'row'),
            name: '카메라',
            wifiName: 'server_ssid'));
    expect(tester.widget<Text>(find.byKey(const Key('device_wifi_name'))).data,
        'server_ssid');
    await pumpDetail(
        tester,
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.camera, id: 'row'),
            name: '카메라'));
    expect(tester.widget<Text>(find.byKey(const Key('device_wifi_name'))).data,
        'local_ssid');
  });

  testWidgets('삭제 확인은 Wi-Fi 바꾸기가 있는 기기에만 그 안내를 붙인다', (tester) async {
    await pumpDetail(
        tester,
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.camera, id: 'row'),
            name: '카메라'));
    await tester.tap(find.text('management_delete_device'));
    await tester.pumpAndSettle();
    expect(find.text('management_delete_confirm_wifi'), findsOneWidget);
  });
}

class _WifiNames implements DeviceWifiNameStore {
  _WifiNames(this.values);
  final Map<(String, PairTargetKind, String), String> values;
  @override
  String? load(String account, PairTargetKind kind, String id) =>
      values[(account, kind, id)];
  @override
  Future<void> save(
          String account, PairTargetKind kind, String id, String ssid) async =>
      values[(account, kind, id)] = ssid;
  @override
  Stream<String?> watch(String account, PairTargetKind kind, String id) =>
      Stream.value(load(account, kind, id));
  @override
  Future<void> clearAll() async => values.clear();
}
