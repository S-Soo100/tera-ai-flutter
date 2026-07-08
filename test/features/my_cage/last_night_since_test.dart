import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/presentation/highlights_controller.dart';

void main() {
  group('lastNightSince (어제 22:00)', () {
    test('오전 → 어제 22:00', () {
      expect(lastNightSince(DateTime(2026, 7, 8, 10)),
          DateTime(2026, 7, 7, 22));
    });
    test('월 경계', () {
      expect(lastNightSince(DateTime(2026, 8, 1, 3)),
          DateTime(2026, 7, 31, 22));
    });
  });
  group('lastNightEnd', () {
    test('06시 이후 → 오늘 06:00', () {
      expect(lastNightEnd(DateTime(2026, 7, 8, 15)),
          DateTime(2026, 7, 8, 6));
    });
    test('06시 이전 → 현재 시각', () {
      final now = DateTime(2026, 7, 8, 3, 30);
      expect(lastNightEnd(now), now);
    });
  });
}
