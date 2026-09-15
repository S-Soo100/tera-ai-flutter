import 'package:flutter/material.dart';
import 'pet.dart';

const _unchanged = Object();

String? validatePetName(String value, Iterable<Pet> pets,
    {String? excludingId}) {
  final name = value.trim();
  if (name.isEmpty) return 'pet_form_required';
  if (name.characters.length > 10) return 'pet_form_name_length';
  if (pets.any((pet) => pet.id != excludingId && pet.name.trim() == name)) {
    return 'pet_form_duplicate';
  }
  return null;
}

String? validatePetWeight(String value) {
  if (value.trim().isEmpty) return null;
  final weight = double.tryParse(value.trim());
  return weight == null || !weight.isFinite || weight < 0
      ? 'pet_form_weight_invalid'
      : null;
}

/// A draft is separate from the mutable Hive Pet. A failed save cannot change
/// the profile displayed elsewhere. Nullable copy arguments support clearing.
@immutable
class PetFormDraft {
  const PetFormDraft({
    this.name = '',
    this.speciesId,
    this.speciesName = '',
    this.morph,
    this.sex = 'unknown',
    this.birthDate,
    this.adoptionDate,
    this.weight = '',
    this.memo = '',
    this.photoPath,
    this.groupId,
  });

  factory PetFormDraft.fromPet(Pet? pet) => pet == null
      ? const PetFormDraft()
      : PetFormDraft(
          name: pet.name,
          speciesId: pet.speciesId,
          speciesName: pet.speciesName,
          morph: pet.morph,
          sex: pet.sex,
          birthDate: pet.birthDate,
          adoptionDate: pet.adoptionDate,
          weight: pet.weight == null
              ? ''
              : pet.weight!.isFinite &&
                      pet.weight == pet.weight!.roundToDouble()
                  ? pet.weight!.toInt().toString()
                  : pet.weight.toString(),
          memo: pet.memo ?? '',
          photoPath: pet.photoPath,
          groupId: pet.enclosureId,
        );

  final String name;
  final String? speciesId;
  final String speciesName;
  final String? morph;
  final String sex;
  final DateTime? birthDate;
  final DateTime? adoptionDate;
  final String weight;
  final String memo;
  final String? photoPath;
  final String? groupId;

  PetFormDraft copyWith({
    String? name,
    Object? speciesId = _unchanged,
    String? speciesName,
    Object? morph = _unchanged,
    String? sex,
    Object? birthDate = _unchanged,
    Object? adoptionDate = _unchanged,
    String? weight,
    String? memo,
    Object? photoPath = _unchanged,
    Object? groupId = _unchanged,
  }) =>
      PetFormDraft(
        name: name ?? this.name,
        speciesId: identical(speciesId, _unchanged)
            ? this.speciesId
            : speciesId is String
                ? speciesId
                : null,
        speciesName: speciesName ?? this.speciesName,
        morph: identical(morph, _unchanged)
            ? this.morph
            : morph is String
                ? morph
                : null,
        sex: sex ?? this.sex,
        birthDate: identical(birthDate, _unchanged)
            ? this.birthDate
            : birthDate is DateTime
                ? birthDate
                : null,
        adoptionDate: identical(adoptionDate, _unchanged)
            ? this.adoptionDate
            : adoptionDate is DateTime
                ? adoptionDate
                : null,
        weight: weight ?? this.weight,
        memo: memo ?? this.memo,
        photoPath: identical(photoPath, _unchanged)
            ? this.photoPath
            : photoPath is String
                ? photoPath
                : null,
        groupId: identical(groupId, _unchanged)
            ? this.groupId
            : groupId is String
                ? groupId
                : null,
      );

  bool sameInput(PetFormDraft other) =>
      name == other.name &&
      speciesId == other.speciesId &&
      speciesName == other.speciesName &&
      morph == other.morph &&
      sex == other.sex &&
      birthDate == other.birthDate &&
      adoptionDate == other.adoptionDate &&
      weight == other.weight &&
      memo == other.memo &&
      photoPath == other.photoPath &&
      groupId == other.groupId;

  Pet toPet({required String id, Pet? original}) => Pet(
        id: id,
        name: name.trim(),
        speciesId: speciesId!,
        speciesName: speciesName,
        morph: morph,
        sex: sex,
        birthDate: birthDate,
        adoptionDate: adoptionDate,
        weight: weight.trim().isEmpty ? null : double.parse(weight.trim()),
        memo: memo.trim().isEmpty ? null : memo.trim(),
        photoPath: photoPath,
        // Assignment is a separate, history-aware operation, never a profile write.
        enclosureId: original?.enclosureId,
        createdAt: original?.createdAt,
        updatedAt: original?.updatedAt,
      );
}
