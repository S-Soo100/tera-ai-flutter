import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/chart_time_axis.dart';

void main() {
  group('chartTimeTicks — 6시간 경계 눈금', () {
    test('전날 19:00 ~ 당일 14:00 → 00·06·12시 3개', () {
      final ticks = chartTimeTicks(
        from: DateTime(2026, 8, 4, 19),
        to: DateTime(2026, 8, 5, 14),
      );
      expect(ticks.map((t) => t.at.hour).toList(), [0, 6, 12]);
    });

    test('position은 구간 내 비율 — 선과 같은 자리를 가리켜야 한다', () {
      // 19:00 ~ 익일 07:00 = 12시간. 00시는 5시간째 → 5/12.
      final ticks = chartTimeTicks(
        from: DateTime(2026, 8, 4, 19),
        to: DateTime(2026, 8, 5, 7),
      );
      expect(ticks, hasLength(2)); // 00시, 06시
      expect(ticks[0].position, closeTo(5 / 12, 1e-9));
      expect(ticks[1].position, closeTo(11 / 12, 1e-9));
    });

    test('구간 밖 경계는 버린다', () {
      final ticks = chartTimeTicks(
        from: DateTime(2026, 8, 5, 7),
        to: DateTime(2026, 8, 5, 11),
      );
      expect(ticks, isEmpty); // 06시는 from 이전, 12시는 to 이후
    });

    test('from이 정확히 경계면 포함하고 position 0', () {
      final ticks = chartTimeTicks(
        from: DateTime(2026, 8, 5, 6),
        to: DateTime(2026, 8, 5, 13),
      );
      expect(ticks.map((t) => t.at.hour).toList(), [6, 12]);
      expect(ticks.first.position, 0);
    });

    test('to가 정확히 경계면 포함하고 position 1', () {
      final ticks = chartTimeTicks(
        from: DateTime(2026, 8, 5, 7),
        to: DateTime(2026, 8, 5, 12),
      );
      expect(ticks, hasLength(1));
      expect(ticks.single.position, 1);
    });

    test('폭이 0이면 빈 목록 — 0으로 나누지 않는다', () {
      final t = DateTime(2026, 8, 5, 12);
      expect(chartTimeTicks(from: t, to: t), isEmpty);
    });

    test('from > to면 빈 목록', () {
      expect(
        chartTimeTicks(
          from: DateTime(2026, 8, 5, 12),
          to: DateTime(2026, 8, 5, 6),
        ),
        isEmpty,
      );
    });

    test('일 경계를 넘어도 순서가 유지된다', () {
      final ticks = chartTimeTicks(
        from: DateTime(2026, 8, 4, 17),
        to: DateTime(2026, 8, 5, 20),
      );
      expect(
        ticks.map((t) => '${t.at.day}/${t.at.hour}').toList(),
        ['4/18', '5/0', '5/6', '5/12', '5/18'],
      );
      // position은 단조 증가해야 한다.
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i].position, greaterThan(ticks[i - 1].position));
      }
    });
  });

  group('ChartTimeTick.hour12 / isAm — 오전·오후 12시간 표기', () {
    ChartTimeTick tickAt(int hour) => chartTimeTicks(
          from: DateTime(2026, 8, 5, hour),
          to: DateTime(2026, 8, 5, hour).add(const Duration(minutes: 1)),
        ).single;

    test('자정은 오전 12시', () {
      final t = tickAt(0);
      expect(t.isAm, isTrue);
      expect(t.hour12, 12);
    });

    test('정오는 오후 12시', () {
      final t = tickAt(12);
      expect(t.isAm, isFalse);
      expect(t.hour12, 12);
    });

    test('Figma 표기와 일치 — 06시=오전 6시, 18시=오후 6시', () {
      expect(tickAt(6).isAm, isTrue);
      expect(tickAt(6).hour12, 6);
      expect(tickAt(18).isAm, isFalse);
      expect(tickAt(18).hour12, 6);
    });
  });
}
