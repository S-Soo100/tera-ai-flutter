import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';

ManagementItem item(String id, ManagementKind kind,
        {String? group, String? name}) =>
    ManagementItem(
        key: ManagementKey(kind: kind, id: id),
        name: name ?? id,
        groupId: group);
void main() {
  test(
      'name limit counts graphemes including emoji and spaces, not UTF16 units',
      () {
    expect(validateManagementName('👨‍👩‍👧‍👦' * 10, const []), isNull);
    expect(
        validateManagementName('가' * 11, const []), 'management_name_length');
    expect(validateManagementName(' 카메라 1 ', ['카메라 1']),
        'management_name_duplicate');
    expect(validateManagementName('   ', const []), 'management_name_required');
  });
  test(
      'new defaults start at one, skip collisions without renaming existing names',
      () {
    expect(nextManagementName('사육장', []), '사육장 1');
    expect(nextManagementName('카메라', ['카메라', '카메라 1', '카메라 3']), '카메라 2');
    expect(nextManagementName('사육 환경', ['사육 환경 1']), '사육 환경 2');
  });
  test(
      'ungrouped items order cage camera pet and add group uses total composition',
      () {
    final items = [
      item('p', ManagementKind.pet),
      item('c', ManagementKind.camera),
      item('d', ManagementKind.device)
    ];
    final inventory = ManagementInventory(groups: const [], items: items);
    expect(inventory.ungrouped.map((i) => i.key.id), ['d', 'c', 'p']);
    expect(inventory.canAddGroup, isTrue);
    expect(
        ManagementInventory(
            groups: [const ManagementGroup(id: 'g', name: 'saved')],
            items: [item('p', ManagementKind.pet, group: 'g')]).canAddGroup,
        isFalse);
    expect(
        ManagementInventory(groups: [
          const ManagementGroup(id: 'g', name: 'saved')
        ], items: [
          item('p', ManagementKind.pet, group: 'g'),
          item('c', ManagementKind.camera, group: 'g')
        ]).canAddGroup,
        isTrue);
  });
  test('one item alone is valid and replacing same kind never permits two', () {
    var draft = GroupEditDraft(name: 'one');
    draft = draft.select(item('a', ManagementKind.camera));
    expect(draft.members.length, 1);
    draft = draft.select(item('b', ManagementKind.camera));
    expect(draft.members.single.id, 'b');
    draft = draft.select(item('b', ManagementKind.camera));
    expect(draft.members, isEmpty);
  });
  test(
      'moving group uses original membership for compare and swap, not display name',
      () {
    final member = item('p', ManagementKind.pet, group: 'old');
    final draft = GroupEditDraft(name: 'new').select(member);
    expect(draft.expectedGroups[member.key], 'old');
    expect(draft.requiresMoveConfirmation(member), isTrue);
  });
}
