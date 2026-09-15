import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/media_repository.dart';
import '../domain/pet.dart';
import '../domain/pet_form_draft.dart';
import '../domain/pet_form_state.dart';
import 'my_pets_providers.dart';

final petFormProvider = StateNotifierProvider.autoDispose
    .family<PetFormNotifier, PetFormState, PetFormSession>((ref, session) {
  return PetFormNotifier(session);
});

/// File storage remains behind a provider/repository boundary. A unique storage
/// key never overwrites an existing avatar before a profile save succeeds.
final petFormPhotoStoreProvider =
    Provider<Future<String> Function(String, String)>((ref) {
  return (petId, path) async {
    if (ref.read(currentUserProvider) != null) {
      return ref.read(mediaRepositoryProvider).uploadPetAvatar(
          petId: '$petId/${const Uuid().v4()}', file: File(path));
    }
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/pet_photos');
    await directory.create(recursive: true);
    final extension = path.split('.').last;
    final file = await File(path)
        .copy('${directory.path}/${const Uuid().v4()}.$extension');
    return file.path;
  };
});

final petFormDefaultSaveProvider = Provider<PetFormSave>((ref) {
  return (pet, groupId) async {
    final pets = ref.read(petListProvider);
    final notifier = ref.read(petListProvider.notifier);
    // Re-check on submit, including when returning from another form.
    final error = validatePetName(pet.name, pets, excludingId: pet.id);
    if (error != null) throw PetFormValidationException(error);
    if (groupId != pet.enclosureId) {
      throw const PetFormValidationException('pet_form_group_unavailable');
    }
    if (pets.any((existing) => existing.id == pet.id)) {
      await notifier.update(pet);
    } else {
      await notifier.add(pet);
    }
  };
});

class PetFormValidationException implements Exception {
  const PetFormValidationException(this.key);
  final String key;
}

class PetFormNotifier extends StateNotifier<PetFormState> {
  PetFormNotifier(this.session) : super(PetFormState(draft: session.initial));
  final PetFormSession session;
  String? _uploadedSource;
  String? _uploadedPath;

  void change(PetFormDraft draft) {
    if (state.saving) return;
    state = PetFormState(draft: draft, submitted: state.submitted);
  }

  void confirmExit() {
    state = PetFormState(draft: state.draft, exitConfirmed: true);
  }

  void showError(String key) {
    if (mounted) {
      state = PetFormState(
          draft: state.draft, submitted: state.submitted, errorKey: key);
    }
  }

  Future<bool> save({
    required PetFormSave persist,
    required Future<String> Function(String, String) storePhoto,
    required Iterable<Pet> peers,
  }) async {
    if (state.saving) return false;
    final draft = state.draft;
    final nameError =
        validatePetName(draft.name, peers, excludingId: session.id);
    if (nameError != null ||
        draft.speciesId == null ||
        validatePetWeight(draft.weight) != null) {
      state = PetFormState(draft: draft, submitted: true);
      return false;
    }
    state = PetFormState(draft: draft, submitted: true, saving: true);
    try {
      var savedDraft = draft;
      final photo = draft.photoPath;
      if (photo != null &&
          photo != session.initial.photoPath &&
          !photo.startsWith('https://') &&
          !photo.startsWith('http://')) {
        if (_uploadedSource != photo) {
          _uploadedPath = await storePhoto(session.id, photo);
          _uploadedSource = photo;
        }
        savedDraft = draft.copyWith(photoPath: _uploadedPath);
      }
      if (!mounted) return false;
      await persist(
          savedDraft.toPet(id: session.id, original: session.original),
          draft.groupId);
      if (!mounted) return false;
      state = PetFormState(draft: draft, submitted: true, saved: true);
      return true;
    } catch (error) {
      if (mounted) {
        state = PetFormState(
            draft: draft,
            submitted: true,
            errorKey: error is PetFormValidationException
                ? error.key
                : 'pet_form_save_failed');
      }
      return false;
    }
  }
}
