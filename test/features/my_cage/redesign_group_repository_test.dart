import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';

void main() {
  test('group deletion uses one atomic RPC and rejects missing server support',
      () async {
    var calls = 0;
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (name, params) async {
          calls++;
          expect(name, 'redesign_delete_group_v1');
          expect(params, {'p_group_id': 'g', 'p_request_id': 'request'});
          return {'group_id': 'g', 'deleted': true};
        });
    await repo.deleteGroup('g', requestId: 'request');
    expect(calls, 1);
    final unavailable = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async {
          throw const PostgrestException(
              message: 'missing function', code: 'PGRST202');
        });
    await expectLater(
        unavailable.deleteGroup('g', requestId: 'request'),
        throwsA(isA<ManagementFailure>()
            .having((e) => e.key, 'key', 'management_server_unsupported')));
  });
  test(
      'inventory preserves existing names, standalone pets and actual identifiers',
      () async {
    final repo = RedesignGroupRepository(
        loadRows: (table) async => switch (table) {
              'enclosures' => [
                  {'id': 'g', 'name': 'old name longer than ten'}
                ],
              'devices' => [
                  {
                    'id': 'd',
                    'name': '사육장',
                    'device_id': 'terra-iot-real',
                    'enclosure_id': 'g',
                    'is_online': false
                  }
                ],
              'cameras' => [
                  {
                    'id': 'c',
                    'name': '카메라',
                    'camera_id': 'p4-real',
                    'enclosure_id': null,
                    'is_online': true
                  }
                ],
              'pets' => [
                  {
                    'id': 'p',
                    'name': 'pet',
                    'morph': 'old morph',
                    'enclosure_id': null
                  }
                ],
              _ => [],
            },
        rpc: (_, __) async => null);
    final inventory = await repo.load();
    expect(inventory.groups.single.name, 'old name longer than ten');
    expect(inventory.groups.single.number, isNull);
    expect(inventory.ungrouped.map((i) => i.key.kind),
        [ManagementKind.camera, ManagementKind.pet]);
    expect(inventory.items.first.hardwareId, 'terra-iot-real');
  });
  test(
      'inventory excludes tombstoned pets but preserves legacy rows without the column',
      () async {
    final repo = RedesignGroupRepository(
        loadRows: (table) async => table == 'pets'
            ? [
                {'id': 'legacy', 'name': 'Legacy'},
                {'id': 'active', 'name': 'Active', 'deleted_at': null},
                {
                  'id': 'deleted',
                  'name': 'Deleted',
                  'deleted_at': '2026-09-15T01:00:00Z'
                },
              ]
            : [],
        rpc: (_, __) async => null);
    expect((await repo.load()).items.map((item) => item.key.id),
        ['legacy', 'active']);
  });
  test('save serializes IDs and prior groups through one atomic RPC', () async {
    var calls = 0;
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (name, params) async {
          calls++;
          expect(name, 'redesign_save_group_v1');
          expect(params['p_camera_id'], 'cam');
          expect(params['p_device_id'], isNull);
          expect(params['p_expected_members'], [
            {'kind': 'camera', 'id': 'cam', 'group_id': 'old'}
          ]);
          return {'group_id': 'new'};
        });
    final draft = GroupEditDraft(name: '사육 환경 1').select(const ManagementItem(
        key: ManagementKey(kind: ManagementKind.camera, id: 'cam'),
        name: 'camera',
        groupId: 'old'));
    expect(await repo.saveGroup(draft, requestId: 'request'), 'new');
    expect(calls, 1);
  });
  test('default-name intent is allocated atomically by the server', () async {
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (name, params) async {
          expect(params['p_name'], isNull);
          return {'group_id': 'new'};
        });
    final draft = GroupEditDraft(name: 'preview 1', useDefaultName: true)
        .select(const ManagementItem(
            key: ManagementKey(kind: ManagementKind.camera, id: 'cam'),
            name: 'camera'));
    expect(await repo.saveGroup(draft, requestId: 'request'), 'new');
  });
  test('empty mutation response cannot be reported as rename success',
      () async {
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [], rpc: (_, __) async => null);
    expect(
        repo.rename(
            const ManagementKey(kind: ManagementKind.camera, id: 'c'), 'name'),
        throwsA(isA<ManagementFailure>()));
  });
  test(
      'missing RPC is unsupported, never falls back to direct delete or update',
      () async {
    var calls = 0;
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async {
          calls++;
          throw const PostgrestException(message: 'missing', code: 'PGRST202');
        });
    expect(
        repo.unlink(const ManagementKey(kind: ManagementKind.camera, id: 'c'),
            requestId: 'r'),
        throwsA(isA<ManagementFailure>()
            .having((e) => e.key, 'key', 'management_server_unsupported')));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });
}
