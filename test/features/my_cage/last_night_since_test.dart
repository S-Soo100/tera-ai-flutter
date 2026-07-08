import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/presentation/highlights_controller.dart';

void main() {
  group('lastNightSince', () {
    test('오전 → 어제 18:00', () {
      expect(lastNightSince(DateTime(2026, 7, 8, 10)),
          DateTime(2026, 7, 7, 18));
    });
    test('늦은 밤 → 여전히 어제 18:00', () {
      expect(lastNightSince(DateTime(2026, 7, 8, 23)),
          DateTime(2026, 7, 7, 18));
    });
    test('월 경계', () {
      expect(lastNightSince(DateTime(2026, 8, 1, 9)),
          DateTime(2026, 7, 31, 18));
    });
  });
}
