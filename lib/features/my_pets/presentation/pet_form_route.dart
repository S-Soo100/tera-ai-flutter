import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/data/redesign_group_repository.dart';
import '../../my_cage/presentation/device_management_controller.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../../home/domain/enclosure_set.dart';
import '../../home/presentation/home_set_providers.dart';
import '../data/redesign_pet_repository.dart';
import '../domain/pet.dart';
import '../domain/pet_form_state.dart';
import 'my_pets_providers.dart';
import 'pet_add_screen.dart';
import 'pet_edit_screen.dart';
import 'pet_form_providers.dart';
import 'pet_management_screen.dart';

final redesignPetRepositoryProvider = Provider<RedesignPetRepository?>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return null;
  return RedesignPetRepository.supabase(
      ref.watch(supabaseClientProvider), userId);
});

final petProfileAndGroupSaveProvider = Provider<PetFormSave>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  var alive = true;
  ref.onDispose(() => alive = false);
  return (pet, groupId) async {
    if (!alive || ref.read(currentUserProvider)?.id != userId) {
      throw const PetFormValidationException('management_auth_changed');
    }
    final refresh = ref.read(managementMutationCompletedProvider);
    final notifier = ref.read(petListProvider.notifier);
    try {
      if (groupId == pet.enclosureId) {
        await ref.read(petFormDefaultSaveProvider)(pet, groupId);
      } else {
        final repository = ref.read(redesignPetRepositoryProvider);
        if (repository == null) {
          throw const PetFormValidationException('management_auth_changed');
        }
        await repository.save(pet, groupId, expectedGroupId: pet.enclosureId);
        if (!alive) return;
        await notifier.syncFromRemote();
      }
      if (alive) refresh();
    } on ManagementFailure catch (error) {
      throw PetFormValidationException(error.key);
    }
  };
});

/// Every pet deletion entry point shares the history-preserving RPC. It never
/// falls back to pets.delete() when the contract is unavailable.
final deleteRedesignPetProvider = Provider<Future<void> Function(Pet)>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  var alive = true;
  ref.onDispose(() => alive = false);
  return (pet) async {
    if (!alive || ref.read(currentUserProvider)?.id != userId) {
      throw const ManagementFailure('management_auth_changed');
    }
    final repository = ref.read(redesignPetRepositoryProvider);
    if (repository == null) {
      throw const ManagementFailure('management_auth_changed');
    }
    final notifier = ref.read(petListProvider.notifier);
    final refresh = ref.read(managementMutationCompletedProvider);
    await repository.delete(pet);
    if (!alive) return;
    await notifier.syncFromRemote();
    if (alive) refresh();
  };
});

class PetFormRoute extends ConsumerWidget {
  const PetFormRoute({super.key, this.petId, this.initialGroupId});
  final String? petId;
  final String? initialGroupId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petListProvider);
    final groups = ref.watch(enclosuresProvider).valueOrNull ?? const [];
    final sets = {
      for (final set in ref.watch(enclosureSetsProvider).valueOrNull ??
          const <EnclosureSet>[])
        set.enclosure.id: set
    };
    final options = [
      for (final (index, group) in groups.indexed)
        if (!pets.any((pet) => pet.id != petId && pet.enclosureId == group.id))
          PetFormGroupOption(
              id: group.id,
              name: group.name,
              number: index + 1,
              hasDevice: sets[group.id]?.device != null,
              hasCamera: sets[group.id]?.camera != null)
    ];
    final save = ref.watch(petProfileAndGroupSaveProvider);
    return petId == null
        ? PetAddScreen(
            groups: options, onSave: save, initialGroupId: initialGroupId)
        : PetEditScreen(petId: petId!, groups: options, onSave: save);
  }
}

class PetManagementRoute extends ConsumerWidget {
  const PetManagementRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PetManagementScreen(onDelete: ref.watch(deleteRedesignPetProvider));
}
