import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/domain/pet_registration_catalog.dart';
import 'package:vivanaut/features/wiki/domain/morph_genetics.dart';

void main() {
  test('registration preserves morph and line-bred source identities', () {
    final data = MorphGeneticsData.fromJson(jsonDecode(
        File('assets/data/morphs/crested-gecko.json').readAsStringSync()));
    final choices = petRegistrationChoices(data);
    expect(choices.length, data.morphs.length + data.lineBredTraits.length);
    expect(choices.map((c) => c.id).toSet().length, choices.length);
    expect(choices.any((c) => c.id == 'trait:harlequin'), isTrue);
    expect(choices.any((c) => c.id == 'morph:axanthic'), isTrue);
  });
}
