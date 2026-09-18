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
  const PetFormGroupOption(
      {required this.id,
      required this.name,
      this.number,
      this.hasDevice = false,
      this.hasCamera = false,
      this.deviceName,
      this.cameraName});
  final String id;
  final String name;

  /// 등록 완료 뒤 연결 카드(Figma 994:13307)에 보이는 기기 이름.
  final String? deviceName, cameraName;

  /// 목록 순서 기반 자동 이름 번호(Figma 1043:3649 AutoName '그룹 N').
  final int? number;

  /// 카드 오른쪽 사육장·카메라 아이콘 표시 여부.
  final bool hasDevice, hasCamera;
}

/// The handler must persist profile + history-aware assignment as one logical
/// save, safely retrying the same pet ID after a partially completed request.
typedef PetFormSave = Future<void> Function(Pet pet, String? groupId);
