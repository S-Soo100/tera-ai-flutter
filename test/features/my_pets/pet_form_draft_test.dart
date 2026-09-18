import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/domain/pet_form_draft.dart';

void main() {
  Pet pet({String id = 'one', String name = '도도'}) => Pet(
        id: id,
        name: name,
        speciesId: 'legacy-species',
        speciesName: '기존 종',
        morph: '기존 모프',
        photoPath: 'old.jpg',
        enclosureId: 'group',
        createdAt: DateTime(2020),
      );
  test('counts user-perceived characters and rejects eleven', () {
    expect(validatePetName('👩‍👩‍👧‍👦' * 10, []), isNull);
    expect(validatePetName('한' * 11, []), 'pet_form_name_length');
    expect(validatePetName('  ', []), 'pet_form_required');
  });
  test('duplicates normalize trim but own unchanged name is valid', () {
    expect(validatePetName(' 도도 ', [pet()]), 'pet_form_duplicate');
    expect(validatePetName(' 도도 ', [pet()], excludingId: 'one'), isNull);
  });
  test(
      'edit copy preserves legacy species morph and assignment without mutating source',
      () {
    final original = pet();
    final draft = PetFormDraft.fromPet(original).copyWith(name: '수정');
    final result = draft.toPet(id: original.id, original: original);
    expect(result.speciesId, original.speciesId);
    expect(result.speciesName, original.speciesName);
    expect(result.morph, original.morph);
    expect(result.enclosureId, original.enclosureId);
    expect(result.createdAt, original.createdAt);
    expect(original.name, '도도');
  });
  test('dirty comparison includes photo removal and cleared date', () {
    final initial = PetFormDraft.fromPet(pet());
    expect(initial.sameInput(initial.copyWith()), isTrue);
    expect(initial.sameInput(initial.copyWith(photoPath: null)), isFalse);
    final dated = initial.copyWith(birthDate: DateTime(2020));
    expect(dated.sameInput(dated.copyWith(birthDate: null)), isFalse);
  });
  test('invalid optional weight is not silently discarded', () {
    expect(validatePetWeight('NaN'), 'pet_form_weight_invalid');
    expect(validatePetWeight('-1'), 'pet_form_weight_invalid');
    expect(validatePetWeight('1.2.3'), 'pet_form_weight_invalid');
    expect(validatePetWeight('0'), isNull);
    expect(validatePetWeight(''), isNull);
  });
}
