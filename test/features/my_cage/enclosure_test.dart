import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';

void main() {
  group('Enclosure.fromJson', () {
    test('완전한 JSON → 모든 필드 매핑', () {
      final e = Enclosure.fromJson({
        'id': 'enc-1',
        'owner_id': 'user-1',
        'name': '테스트 사육장',
        'species': 'crested_gecko',
        'note': '거실 창가',
        'created_at': '2026-07-06T00:00:00Z',
        'updated_at': '2026-07-06T00:00:00Z',
      });
      expect(e.id, 'enc-1');
      expect(e.name, '테스트 사육장');
      expect(e.species, 'crested_gecko');
      expect(e.note, '거실 창가');
      expect(e.createdAt.isAtSameMomentAs(DateTime.utc(2026, 7, 6)), isTrue);
    });

    test('nullable 필드(species, note) 누락 → null', () {
      final e = Enclosure.fromJson({
        'id': 'enc-2',
        'name': '사육장2',
        'created_at': '2026-07-06T00:00:00Z',
      });
      expect(e.species, isNull);
      expect(e.note, isNull);
    });

    test('필수 필드 누락 → 방어적 기본값', () {
      final e = Enclosure.fromJson(<String, dynamic>{});
      expect(e.id, '');
      expect(e.name, '');
      expect(e.createdAt, isA<DateTime>());
    });
  });
}
