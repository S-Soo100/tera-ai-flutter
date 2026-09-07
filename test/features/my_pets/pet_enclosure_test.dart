import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_pets/domain/pet.dart';

Pet _pet({String? enclosureId}) => Pet(
      id: 'pet-1',
      name: '젤리',
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
      enclosureId: enclosureId,
    );

void main() {
  group('Pet.enclosureId', () {
    test('미지정이면 null — 기존 레코드 호환', () {
      expect(_pet().enclosureId, isNull);
    });

    test('생성자로 지정 가능', () {
      expect(_pet(enclosureId: 'enc-1').enclosureId, 'enc-1');
    });

    test('mutable — 배정/해제를 직접 대입으로 처리', () {
      final p = _pet();
      p.enclosureId = 'enc-9';
      expect(p.enclosureId, 'enc-9');
      p.enclosureId = null;
      expect(p.enclosureId, isNull);
    });
  });
}
