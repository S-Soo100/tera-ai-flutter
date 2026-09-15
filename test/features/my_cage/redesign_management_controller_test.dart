import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';

void main() {
  test('delete failure preserves members and retries the same atomic request',
      () async {
    final requests = <String>[];
    final controller = GroupEditorController(
        RedesignGroupRepository(
            loadRows: (_) async => [],
            rpc: (name, params) async {
              expect(name, 'redesign_delete_group_v1');
              requests.add(params['p_request_id']! as String);
              if (requests.length == 1) {
                throw const ManagementFailure('management_server_unsupported');
              }
              return {'group_id': 'g', 'deleted': true};
            }),
        GroupEditDraft(
            groupId: 'g',
            name: 'saved',
            members: {
              const ManagementKey(kind: ManagementKind.camera, id: 'c'),
              const ManagementKey(kind: ManagementKind.pet, id: 'p'),
            },
            step: GroupEditorStep.review));
    addTearDown(controller.dispose);
    expect(await controller.deleteGroup(), false);
    expect(controller.state.members.length, 2);
    expect(controller.state.name, 'saved');
    expect(controller.state.finished, false);
    expect(controller.state.errorKey, 'management_server_unsupported');
    expect(await controller.deleteGroup(), true);
    expect(controller.state.finished, true);
    expect(requests[0], requests[1]);
    expect(await controller.deleteGroup(), false);
    expect(requests.length, 2);
  });

  test('failed group save preserves the name, selected items and review step',
      () async {
    final member = const ManagementItem(
        key: ManagementKey(kind: ManagementKind.camera, id: 'c'), name: 'Cam');
    final inventory = ManagementInventory(groups: [], items: [member]);
    final controller = GroupEditorController(
        RedesignGroupRepository(
            loadRows: (_) async => [],
            rpc: (_, __) async =>
                throw const ManagementFailure('management_server_unsupported')),
        GroupEditDraft(name: '환경')
            .select(member)
            .copy(step: GroupEditorStep.review));
    addTearDown(controller.dispose);
    expect(await controller.save(inventory), isFalse);
    expect(controller.state.name, '환경');
    expect(controller.state.members.single.id, 'c');
    expect(controller.state.step, GroupEditorStep.review);
    expect(controller.state.errorKey, 'management_server_unsupported');
    expect(controller.state.saving, isFalse);
  });
  test('no member and duplicate device name never send a write', () async {
    var calls = 0;
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async {
          calls++;
          return null;
        });
    final inventory = ManagementInventory(groups: [], items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.device, id: 'd'),
          name: 'taken'),
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'c'),
          name: 'camera'),
    ]);
    final group = GroupEditorController(repo, GroupEditDraft(name: 'new'));
    final device = DeviceEditorController(repo, inventory.items.last);
    addTearDown(group.dispose);
    addTearDown(device.dispose);
    expect(await group.save(inventory), isFalse);
    device.renameDraft('taken');
    expect(await device.save(inventory), isFalse);
    expect(device.state.nameErrorKey, 'management_name_duplicate');
    expect(calls, 0);
  });
}
