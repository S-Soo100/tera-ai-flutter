// 마이페이지 → 사육장 기기 재시작(2026-10-04).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/device_health_repository.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/domain/sys_health.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/features/profile/presentation/device_reboot_screen.dart';

class _DeviceRepo implements DeviceHealthRepository {
  int reboots = 0;
  @override
  Future<String> reboot(String deviceUuid) async {
    reboots++;
    return 'cmd-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ManagementItem _item(String id, String name) => ManagementItem(
    key: ManagementKey(kind: ManagementKind.device, id: id), name: name);

SysHealth _health({bool present = true, bool online = true}) => SysHealth(
    present: present,
    uptimeSeconds: present ? 100 : null,
    isOnline: online,
    statsAt: DateTime.utc(2026, 10, 4));

void main() {
  Future<_DeviceRepo> pump(WidgetTester tester,
      {required List<ManagementItem> items,
      Map<String, SysHealth> health = const {}}) async {
    final repo = _DeviceRepo();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          managementInventoryProvider.overrideWith(
              (ref) async => ManagementInventory(groups: [], items: items)),
          for (final e in health.entries)
            sysHealthProvider((PairTargetKind.device, e.key))
                .overrideWith((ref) => Stream.value(e.value)),
          rebootCommandProvider('cmd-1')
              .overrideWith((ref) => const Stream.empty()),
          deviceHealthRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const DeviceRebootScreen())));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('사육장 기기가 없으면 빈 안내', (tester) async {
    await pump(tester, items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'cam'),
          name: '카메라'),
    ]);
    expect(find.byKey(DeviceRebootScreen.emptyKey), findsOneWidget);
    expect(find.text('카메라'), findsNothing);
  });

  testWidgets('못 하는 기기도 이유와 함께 보이고 누를 수 없다', (tester) async {
    final repo = await pump(tester, items: [
      _item('off', '꺼진 사육장'),
      _item('old', '구 펌웨어'),
    ], health: {
      'off': _health(online: false),
      'old': _health(present: false),
    });
    expect(find.text('device_reboot_status_offline'), findsOneWidget);
    expect(find.text('device_reboot_status_old_firmware'), findsOneWidget);
    await tester.tap(find.byKey(DeviceRebootScreen.rowKey('off')));
    await tester.tap(find.byKey(DeviceRebootScreen.rowKey('old')));
    await tester.pumpAndSettle();
    expect(find.text('reboot_ok'), findsNothing);
    expect(repo.reboots, 0);
  });

  testWidgets('켜진 신 펌웨어 기기는 확인 후 재시작 요청, 진행 중 표시', (tester) async {
    final repo = await pump(tester,
        items: [_item('dev-1', '사육장 1')], health: {'dev-1': _health()});
    expect(find.text('device_reboot_status_ready'), findsOneWidget);
    await tester.tap(find.byKey(DeviceRebootScreen.rowKey('dev-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('device_reboot_confirm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reboot_ok')));
    await tester.pumpAndSettle();
    expect(repo.reboots, 1);
    expect(find.text('reboot_progress'), findsOneWidget);
    // 진행 중엔 다시 눌러도 확인창이 뜨지 않는다.
    await tester.tap(find.byKey(DeviceRebootScreen.rowKey('dev-1')));
    await tester.pumpAndSettle();
    expect(find.text('reboot_ok'), findsNothing);
    // 2분 타이머가 남지 않게 정리.
    await tester.pumpWidget(const SizedBox());
  });
}
