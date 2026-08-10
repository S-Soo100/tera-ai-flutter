import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/day_window.dart';

void main() {
  group('DayWindow.of — 07:00 경계', () {
    test('07:00 정각은 당일 창의 시작', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 7, 0));
      expect(w.start, DateTime(2026, 8, 5, 7));
      expect(w.end, DateTime(2026, 8, 6, 7));
    });

    test('06:59는 전날 창에 속한다', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 6, 59));
      expect(w.start, DateTime(2026, 8, 4, 7));
      expect(w.end, DateTime(2026, 8, 5, 7));
    });

    test('23:30은 당일 창', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 23, 30));
      expect(w.start, DateTime(2026, 8, 5, 7));
    });

    test('labelDate = 창이 시작한 날짜', () {
      expect(DayWindow.of(DateTime(2026, 8, 5, 3)).labelDate,
          DateTime(2026, 8, 4));
    });

    test('contains — 경계는 start 포함, end 미포함', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 12));
      expect(w.contains(DateTime(2026, 8, 5, 7)), isTrue);
      expect(w.contains(DateTime(2026, 8, 6, 7)), isFalse);
    });

    test('forDate — 특정 날짜의 창 (날짜 스크롤러용)', () {
      final w = DayWindow.forDate(DateTime(2026, 8, 3));
      expect(w.start, DateTime(2026, 8, 3, 7));
      expect(w.end, DateTime(2026, 8, 4, 7));
    });
  });

  group('DayWindow.elapsed — 실제 경과 시간', () {
    test('진행 중인 오늘 18:29 → 07:00부터 11시간 29분', () {
      final w = DayWindow.forDate(DateTime(2026, 8, 5));
      expect(w.elapsed(DateTime(2026, 8, 5, 18, 29)),
          const Duration(hours: 11, minutes: 29));
    });

    test('창이 끝난 지난 날짜 → 24시간 전체', () {
      final w = DayWindow.forDate(DateTime(2026, 8, 3));
      expect(w.elapsed(DateTime(2026, 8, 5, 12)), const Duration(hours: 24));
    });

    test('창 종료 정각도 24시간', () {
      final w = DayWindow.forDate(DateTime(2026, 8, 5));
      expect(
          w.elapsed(DateTime(2026, 8, 6, 7)), const Duration(hours: 24));
    });

    test('창 시작 전(미래 날짜)이면 0 — 음수로 안 간다', () {
      final w = DayWindow.forDate(DateTime(2026, 8, 9));
      expect(w.elapsed(DateTime(2026, 8, 5, 12)), Duration.zero);
    });
  });

  group('DayWindow.chartRange — 전날 19:00 ~ 현재', () {
    test('시작은 전날 19:00, 끝은 현재', () {
      final now = DateTime(2026, 8, 5, 14, 30);
      final r = DayWindow.chartRange(now);
      expect(r.start, DateTime(2026, 8, 4, 19));
      expect(r.end, now);
    });

    test('새벽 02:00에도 시작은 전날(=8/4) 19:00', () {
      final r = DayWindow.chartRange(DateTime(2026, 8, 5, 2));
      expect(r.start, DateTime(2026, 8, 4, 19));
    });
  });
}
