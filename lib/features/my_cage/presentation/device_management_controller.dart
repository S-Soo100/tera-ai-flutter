import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/redesign_group_repository.dart';
import '../domain/redesign_management.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../../my_pets/presentation/pet_assignment_providers.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';

final redesignGroupRepositoryProvider =
    Provider.autoDispose<RedesignGroupRepository?>((ref) {
  final user = ref.watch(currentUserProvider.select((u) => u?.id));
  if (user == null) return null;
  return RedesignGroupRepository.supabase(
      ref.watch(supabaseClientProvider), user);
});
final managementInventoryProvider =
    FutureProvider.autoDispose<ManagementInventory>((ref) {
  final repo = ref.watch(redesignGroupRepositoryProvider);
  if (repo == null) throw const ManagementFailure('management_auth_changed');
  return repo.load();
});

/// Refresh every dependent tab only after a committed mutation. Failed writes
/// keep the editor draft and the last confirmed inventory intact.
final managementMutationCompletedProvider = Provider<VoidCallback>((ref) => () {
      ref.invalidate(managementInventoryProvider);
      ref.invalidate(enclosuresProvider);
      ref.invalidate(deviceListProvider);
      ref.invalidate(camerasProvider);
      ref.invalidate(petListProvider);
      ref.invalidate(petCameraAssignmentsProvider);
    });

/// Widget-scoped ProviderScope overrides inject initial draft/item. Neither
/// inventory refreshes nor failed writes discard unsaved input.
final groupEditorControllerProvider =
    StateNotifierProvider.autoDispose<GroupEditorController, GroupEditDraft>(
        (ref) => throw StateError(
            'GroupEditorController must be scoped by GroupEditorScreen'));
final deviceEditorControllerProvider =
    StateNotifierProvider.autoDispose<DeviceEditorController, DeviceEditDraft>(
        (ref) => throw StateError(
            'DeviceEditorController must be scoped by DeviceDetailScreen'));

class GroupEditorController extends StateNotifier<GroupEditDraft> {
  GroupEditorController(this._repo, GroupEditDraft draft) : super(draft);
  final RedesignGroupRepository _repo;
  String? _requestId;
  void name(String value) {
    if (!state.saving) {
      state = state.copy(name: value, useDefaultName: false);
      _requestId = null;
    }
  }

  void select(ManagementItem item) {
    if (!state.saving) {
      state = state.select(item);
      _requestId = null;
    }
  }

  void step(GroupEditorStep value) {
    if (!state.saving) state = state.copy(step: value);
  }

  bool validateName(ManagementInventory inventory) {
    final original = inventory.group(state.groupId)?.name;
    final error = original == state.name
        ? null
        : validateManagementName(
            state.name,
            state.useDefaultName
                ? const <String>[]
                : inventory.groups
                    .where((g) => g.id != state.groupId)
                    .map((g) => g.name));
    state = state.copy(nameErrorKey: error);
    return error == null;
  }

  Future<bool> save(ManagementInventory inventory) async {
    if (state.saving || !validateName(inventory)) return false;
    if (state.members.isEmpty) {
      state = state.copy(errorKey: 'management_member_required');
      return false;
    }
    if (ManagementKind.values
        .any((kind) => state.members.where((m) => m.kind == kind).length > 1)) {
      state = state.copy(errorKey: 'management_one_per_kind');
      return false;
    }
    state = state.copy(saving: true);
    try {
      final id = await _repo.saveGroup(state,
          requestId: _requestId ??= const Uuid().v4());
      if (!mounted) return false;
      state = state.copy(saving: false, savedGroupId: id);
      return true;
    } catch (error) {
      if (!mounted) return false;
      final key =
          error is ManagementFailure ? error.key : 'management_save_failed';
      state = state.copy(
          saving: false,
          errorKey: key,
          nameErrorKey: key == 'management_name_duplicate' ? key : null);
      return false;
    }
  }
}

class DeviceEditorController extends StateNotifier<DeviceEditDraft> {
  DeviceEditorController(this._repo, this.item)
      : super(DeviceEditDraft(name: item.name));
  final RedesignGroupRepository _repo;
  final ManagementItem item;
  final _requestIds = <String, String>{};
  void renameDraft(String value) {
    if (!state.saving) state = DeviceEditDraft(name: value);
  }

  Future<bool> save(ManagementInventory inventory) async {
    if (state.saving) return false;
    if (state.name == item.name) return true;
    final error = validateManagementName(
        state.name, inventory.deviceNames(excluding: item.key));
    if (error != null) {
      state = DeviceEditDraft(name: state.name, nameErrorKey: error);
      return false;
    }
    return _run(() => _repo.rename(item.key, state.name));
  }

  Future<bool> removeFromGroup(String groupId) => _run(() => _repo.removeMember(
      item.key, groupId,
      requestId: _requestIds.putIfAbsent('remove', () => const Uuid().v4())));
  Future<bool> unlink() => _run(() => _repo.unlink(item.key,
      requestId: _requestIds.putIfAbsent('unlink', () => const Uuid().v4())));
  Future<bool> _run(Future<void> Function() operation) async {
    if (state.saving) return false;
    state = DeviceEditDraft(name: state.name, saving: true);
    try {
      await operation();
      if (!mounted) return false;
      state = DeviceEditDraft(name: state.name, finished: true);
      return true;
    } catch (error) {
      if (!mounted) return false;
      final key =
          error is ManagementFailure ? error.key : 'management_save_failed';
      state = DeviceEditDraft(
          name: state.name,
          errorKey: key,
          nameErrorKey: key == 'management_name_duplicate' ? key : null);
      return false;
    }
  }
}
