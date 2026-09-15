import 'pet.dart';
import 'pet_form_draft.dart';

class PetFormSession {
  PetFormSession({required this.id, this.original, String? initialGroupId})
      : initial = PetFormDraft.fromPet(original)
            .copyWith(groupId: original?.enclosureId ?? initialGroupId);
  final String id;
  final Pet? original;
  final PetFormDraft initial;
}

class PetFormState {
  const PetFormState(
      {required this.draft,
      this.saving = false,
      this.submitted = false,
      this.saved = false,
      this.exitConfirmed = false,
      this.errorKey});
  final PetFormDraft draft;
  final bool saving;
  final bool submitted;
  final bool saved;
  final bool exitConfirmed;
  final String? errorKey;
}

class PetFormGroupOption {
  const PetFormGroupOption({required this.id, required this.name});
  final String id;
  final String name;
}

/// The handler must persist profile + history-aware assignment as one logical
/// save, safely retrying the same pet ID after a partially completed request.
typedef PetFormSave = Future<void> Function(Pet pet, String? groupId);
