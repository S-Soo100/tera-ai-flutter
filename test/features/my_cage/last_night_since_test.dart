import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/presentation/highlights_controller.dart';

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
  group('lastNightDayKey (20:00 경계 — 서버 day_key와 같은 정의)', () {
    test('20시 이전 → 어제 날짜', () {
      expect(lastNightDayKey(DateTime(2026, 9, 10, 10)), '2026-09-09');
    });
    test('20시 이후 → 오늘 날짜', () {
      expect(lastNightDayKey(DateTime(2026, 9, 10, 21)), '2026-09-10');
    });
    test('경계 정각(20:00)부터 오늘', () {
      expect(lastNightDayKey(DateTime(2026, 9, 10, 20)), '2026-09-10');
      expect(lastNightDayKey(DateTime(2026, 9, 10, 19, 59)), '2026-09-09');
    });
    test('월 경계 + 0패딩', () {
      expect(lastNightDayKey(DateTime(2026, 10, 1, 3)), '2026-09-30');
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
