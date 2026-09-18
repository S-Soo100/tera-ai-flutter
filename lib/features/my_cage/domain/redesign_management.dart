import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Characters;

enum ManagementKind { device, camera, pet }

@immutable
class ManagementKey {
  const ManagementKey({required this.kind, required this.id});
  final ManagementKind kind;
  final String id;
  @override
  bool operator ==(Object other) =>
      other is ManagementKey && kind == other.kind && id == other.id;
  @override
  int get hashCode => Object.hash(kind, id);
}

@immutable
class ManagementItem {
  const ManagementItem(
      {required this.key,
      required this.name,
      this.groupId,
      this.hardwareId,
      this.isOnline,
      this.subtitle});
  final ManagementKey key;
  final String name;
  final String? groupId;
  final String? hardwareId;
  final bool? isOnline;
  final String? subtitle;
}

@immutable
class ManagementGroup {
  const ManagementGroup({required this.id, required this.name, this.number});
  final String id;
  final String name;

  /// Null until the server provides a stable creation ordinal. A list index
  /// is not a group number and is never persisted as one.
  final int? number;
}

@immutable
class ManagementInventory {
  ManagementInventory(
      {required List<ManagementGroup> groups,
      required List<ManagementItem> items})
      : groups = List.unmodifiable(groups),
        items = List.unmodifiable(items);
  final List<ManagementGroup> groups;
  final List<ManagementItem> items;
  bool get isEmpty => items.isEmpty && groups.isEmpty;
  List<ManagementItem> members(String groupId) =>
      items.where((i) => i.groupId == groupId).toList()
        ..sort((a, b) => a.key.kind.index.compareTo(b.key.kind.index));
  List<ManagementItem> get ungrouped =>
      items.where((i) => i.groupId == null).toList()
        ..sort((a, b) => a.key.kind.index.compareTo(b.key.kind.index));
  bool get canAddGroup =>
      ungrouped.isNotEmpty || groups.any((g) => members(g.id).length >= 2);
  ManagementGroup? group(String? id) =>
      groups.where((g) => g.id == id).firstOrNull;
  ManagementItem? item(ManagementKey key) =>
      items.where((i) => i.key == key).firstOrNull;
  Iterable<String> deviceNames({ManagementKey? excluding}) => items
      .where((i) => i.key.kind != ManagementKind.pet && i.key != excluding)
      .map((i) => i.name);
}

/// Comparison contract: trim leading/trailing whitespace, otherwise exact
/// Unicode/case comparison, matching the existing pet form rule.
String? validateManagementName(String value, Iterable<String> existing) {
  final name = value.trim();
  if (name.isEmpty) return 'management_name_required';
  if (Characters(name).length > 10) return 'management_name_length';
  if (existing.any((other) => other.trim() == name)) {
    return 'management_name_duplicate';
  }
  return null;
}

String nextManagementName(String prefix, Iterable<String> existing) {
  final names = existing.map((n) => n.trim()).toSet();
  for (var number = 1;; number++) {
    final name = '$prefix $number';
    if (Characters(name).length > 10) {
      throw StateError('No numbered name within ten graphemes');
    }
    if (!names.contains(name)) return name;
  }
}

enum GroupEditorStep { name, members, review }

@immutable
class GroupEditDraft {
  GroupEditDraft(
      {this.groupId,
      required this.name,
      Set<ManagementKey> members = const {},
      Map<ManagementKey, String?> expectedGroups = const {},
      this.step = GroupEditorStep.name,
      this.saving = false,
      this.errorKey,
      this.nameErrorKey,
      this.savedGroupId,
      this.finished = false,
      this.useDefaultName = false})
      : members = Set.unmodifiable(members),
        expectedGroups = Map.unmodifiable(expectedGroups);
  factory GroupEditDraft.existing(
          ManagementGroup group, ManagementInventory inventory) =>
      GroupEditDraft(
          groupId: group.id,
          name: group.name,
          members: inventory.members(group.id).map((i) => i.key).toSet(),
          expectedGroups: {
            for (final item in inventory.members(group.id))
              item.key: item.groupId
          },
          step: GroupEditorStep.review);
  final String? groupId;
  final String name;
  final Set<ManagementKey> members;
  final Map<ManagementKey, String?> expectedGroups;
  final GroupEditorStep step;
  final bool saving;
  final String? errorKey;
  final String? nameErrorKey;
  final String? savedGroupId;
  final bool finished;
  final bool useDefaultName;
  bool requiresMoveConfirmation(ManagementItem item) =>
      item.groupId != null && item.groupId != groupId;
  GroupEditDraft select(ManagementItem item) {
    final next = {...members};
    final already = next.remove(item.key);
    if (!already) {
      next.removeWhere((m) => m.kind == item.key.kind);
      next.add(item.key);
    }
    return copy(
        members: next,
        expectedGroups: {...expectedGroups, item.key: item.groupId});
  }

  GroupEditDraft copy(
          {String? name,
          Set<ManagementKey>? members,
          Map<ManagementKey, String?>? expectedGroups,
          GroupEditorStep? step,
          bool? saving,
          String? errorKey,
          String? nameErrorKey,
          String? savedGroupId,
          bool? finished,
          bool? useDefaultName}) =>
      GroupEditDraft(
          groupId: groupId,
          name: name ?? this.name,
          members: members ?? this.members,
          expectedGroups: expectedGroups ?? this.expectedGroups,
          step: step ?? this.step,
          saving: saving ?? this.saving,
          errorKey: errorKey,
          nameErrorKey: nameErrorKey,
          savedGroupId: savedGroupId ?? this.savedGroupId,
          finished: finished ?? this.finished,
          useDefaultName: useDefaultName ?? this.useDefaultName);
}

@immutable
class DeviceEditDraft {
  const DeviceEditDraft(
      {required this.name,
      this.saving = false,
      this.errorKey,
      this.nameErrorKey,
      this.finished = false});
  final String name;
  final bool saving;
  final String? errorKey;
  final String? nameErrorKey;
  final bool finished;
}
