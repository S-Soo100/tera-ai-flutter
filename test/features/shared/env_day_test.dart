import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/env_day.dart';

void main() {
  group('EnvDay.of', () {
    test('시각을 버리고 자정으로 정규화한다', () {
      final day = EnvDay.of(DateTime(2026, 9, 2, 14, 37, 22));
      expect(day.date, DateTime(2026, 9, 2));
    });

    test('자정 입력은 그대로 그 날이다', () {
      final day = EnvDay.of(DateTime(2026, 9, 2));
      expect(day.date, DateTime(2026, 9, 2));
    });
  });

  group('start / end', () {
    test('start = 자정, end = 다음 날 자정', () {
      final day = EnvDay(DateTime(2026, 9, 2));
      expect(day.start, DateTime(2026, 9, 2));
      expect(day.end, DateTime(2026, 9, 3));
    });

    test('월말 경계 — end가 다음 달 1일로 넘어간다', () {
      final day = EnvDay(DateTime(2026, 9, 30));
      expect(day.end, DateTime(2026, 10, 1));
    });
  });

  group('previous / next', () {
    test('하루 전/후', () {
      final day = EnvDay(DateTime(2026, 9, 2));
      expect(day.previous.date, DateTime(2026, 9, 1));
      expect(day.next.date, DateTime(2026, 9, 3));
    });

    test('월 경계를 달력으로 넘는다', () {
      expect(EnvDay(DateTime(2026, 9, 1)).previous.date, DateTime(2026, 8, 31));
      expect(EnvDay(DateTime(2026, 12, 31)).next.date, DateTime(2027, 1, 1));
    });

    test('윤년 2월 경계', () {
      expect(EnvDay(DateTime(2028, 3, 1)).previous.date, DateTime(2028, 2, 29));
    });
  });

  group('containsNow', () {
    final day = EnvDay(DateTime(2026, 9, 2));

    test('시작 경계는 포함(자정 = 그 날)', () {
      expect(day.containsNow(DateTime(2026, 9, 2)), isTrue);
    });

    test('끝 경계는 제외(다음 자정 = 다음 날)', () {
      expect(day.containsNow(DateTime(2026, 9, 3)), isFalse);
    });

    test('하루 안의 시각은 포함', () {
      expect(day.containsNow(DateTime(2026, 9, 2, 23, 59, 59)), isTrue);
    });

    test('전날 밤은 제외', () {
      expect(day.containsNow(DateTime(2026, 9, 1, 23, 59, 59)), isFalse);
    });
  });

  group('isToday', () {
    test('지금으로 만든 EnvDay는 오늘이다', () {
      expect(EnvDay.of(DateTime.now()).isToday, isTrue);
    });

    test('어제는 오늘이 아니다', () {
      expect(EnvDay.of(DateTime.now()).previous.isToday, isFalse);
    });
  });

  group('동등성', () {
    test('같은 날짜면 같다 (StateProvider 상태 비교에 필요)', () {
      expect(EnvDay(DateTime(2026, 9, 2)), EnvDay(DateTime(2026, 9, 2)));
      expect(
        EnvDay(DateTime(2026, 9, 2)).hashCode,
        EnvDay(DateTime(2026, 9, 2)).hashCode,
      );
    });

    test('다른 날짜면 다르다', () {
      expect(
        EnvDay(DateTime(2026, 9, 2)) == EnvDay(DateTime(2026, 9, 3)),
        isFalse,
      );
    });
  });
}
