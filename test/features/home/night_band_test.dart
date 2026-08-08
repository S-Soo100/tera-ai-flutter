import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/night_band.dart';

void main() {
  group('nightBands — 22:00~06:00 구간을 차트 좌표로', () {
    test('전날 19:00 ~ 당일 14:00 → 밤 한 구간', () {
      final b = nightBands(
        from: DateTime(2026, 8, 4, 19),
        to: DateTime(2026, 8, 5, 14),
      );
      expect(b, hasLength(1));
      // 19시간 폭. 밤 시작(22:00)은 3시간째, 끝(06:00)은 11시간째.
      expect(b.single.start, closeTo(3 / 19, 1e-9));
      expect(b.single.end, closeTo(11 / 19, 1e-9));
    });

    test('구간이 밤 안에서 시작하면 0에서 시작한다 — 앞을 잘라낸다', () {
      final b = nightBands(
        from: DateTime(2026, 8, 5, 2), // 이미 밤 한복판
        to: DateTime(2026, 8, 5, 10),
      );
      expect(b.single.start, 0);
      expect(b.single.end, closeTo(4 / 8, 1e-9)); // 06:00 = 4시간째
    });

    test('구간이 밤 도중에 끝나면 1에서 끝난다 — 뒤를 잘라낸다', () {
      final b = nightBands(
        from: DateTime(2026, 8, 5, 20),
        to: DateTime(2026, 8, 6, 0),
      );
      expect(b.single.start, closeTo(2 / 4, 1e-9)); // 22:00 = 2시간째
      expect(b.single.end, 1);
    });

    test('이틀치면 밤이 두 구간', () {
      final b = nightBands(
        from: DateTime(2026, 8, 4, 12),
        to: DateTime(2026, 8, 6, 12),
      );
      expect(b, hasLength(2));
      expect(b[0].start, lessThan(b[1].start));
    });

    test('밤이 하나도 안 걸치면 빈 목록', () {
      final b = nightBands(
        from: DateTime(2026, 8, 5, 8),
        to: DateTime(2026, 8, 5, 18),
      );
      expect(b, isEmpty);
    });

    test('경계에 딱 붙으면 폭 0짜리는 버린다 — 보이지 않는 띠를 그리지 않는다', () {
      final b = nightBands(
        from: DateTime(2026, 8, 5, 6), // 밤이 끝나는 순간부터
        to: DateTime(2026, 8, 5, 18),
      );
      expect(b, isEmpty);
    });

    test('폭이 0인 구간이면 빈 목록 — 0으로 나누지 않는다', () {
      final t = DateTime(2026, 8, 5, 23);
      expect(nightBands(from: t, to: t), isEmpty);
    });

    test('from > to면 빈 목록', () {
      expect(
        nightBands(
          from: DateTime(2026, 8, 5, 23),
          to: DateTime(2026, 8, 5, 20),
        ),
        isEmpty,
      );
    });

    test('모든 좌표는 0~1 안에 있다', () {
      final b = nightBands(
        from: DateTime(2026, 8, 4, 19),
        to: DateTime(2026, 8, 6, 3),
      );
      for (final s in b) {
        expect(s.start, inInclusiveRange(0, 1));
        expect(s.end, inInclusiveRange(0, 1));
        expect(s.end, greaterThan(s.start));
      }
    });
  });

  group('밤 경계 상수 — §3.1 활동 집계 창과 일치해야 한다', () {
    test('22시 시작, 6시 종료', () {
      expect(kNightStartHour, 22);
      expect(kNightEndHour, 6);
    });
  });
}
