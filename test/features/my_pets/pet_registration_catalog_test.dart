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
  test('initial groups sort names and preserve duplicate source labels', () {
    final groups = petRegistrationGroups([
      (id: 'morph:lilly', name: '릴리 화이트', englishName: 'Lilly White'),
      (id: 'trait:a', name: '아잔틱', englishName: null),
      (id: 'morph:a', name: '아잔틱', englishName: null),
      (id: 'morph:normal', name: '노말', englishName: null),
    ]);
    expect(groups.keys, ['ㄴ', 'ㄹ', 'ㅇ']);
    expect(groups['ㅇ']!.map((c) => c.id), ['morph:a', 'trait:a']);
    expect(groups.values.expand((g) => g).length, 4);
  });

  group('petRegistrationSearch', () {
    const lilly = (id: 'morph:lilly', name: '릴리 화이트', englishName: 'Lilly White');
    const lavender = (id: 'morph:lav', name: '라벤더', englishName: null);
    const diablo = (id: 'morph:dia', name: '디아블로 블랑코', englishName: null);
    const nova = (id: 'morph:nova', name: '수퍼 노바', englishName: null);
    const all = [nova, diablo, lavender, lilly];

    test('initial consonant matches every syllable, not only the first', () {
      expect(petRegistrationMatches('릴리 화이트', 'ㄹ'), [(0, 1), (1, 2)]);
      expect(petRegistrationMatches('라벤더', 'ㄹ'), [(0, 1)]);
      expect(petRegistrationMatches('디아블로 블랑코', 'ㅂ'), [(2, 3), (5, 6)]);
      expect(petRegistrationMatches('수퍼 노바', 'ㅂ'), [(4, 5)]);
      expect(petRegistrationMatches('노말', 'ㄹ'), isEmpty);
    });
    test('mixed initials and syllables match in order', () {
      expect(petRegistrationMatches('릴리 화이트', 'ㄹ리'), [(0, 2)]);
      expect(petRegistrationMatches('릴리 화이트', '화ㅇ'), [(3, 5)]);
      expect(petRegistrationMatches('릴리 화이트', '리화'), isEmpty);
    });
    test('substring search keeps working and ignores case', () {
      expect(petRegistrationMatches('수퍼 노바', '노바'), [(3, 5)]);
      expect(petRegistrationMatches('Lilly White', 'lilly'), [(0, 5)]);
    });
    test('english name matches without highlighting the korean label', () {
      final hits = petRegistrationSearch(all, 'Lilly');
      expect(hits.map((h) => h.choice.id), ['morph:lilly']);
      expect(hits.single.ranges, isEmpty);
    });
    test('results drop initial sections, order by match position then name',
        () {
      final hits = petRegistrationSearch(all, 'ㅂ');
      expect(hits.map((h) => h.choice.name), ['라벤더', '디아블로 블랑코', '수퍼 노바']);
      final l = petRegistrationSearch(all, 'ㄹ');
      expect(l.map((h) => h.choice.name), ['라벤더', '릴리 화이트', '디아블로 블랑코']);
      expect(petRegistrationSearch(all, '없는모프'), isEmpty);
      expect(petRegistrationSearch(all, '   '), isEmpty);
    });
  });
}
