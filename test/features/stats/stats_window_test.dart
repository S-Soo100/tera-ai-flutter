import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/stats/domain/stats_window.dart';

void main() {
  group('창 끝 — 다음 6시간 눈금', () {
    test('Figma가 그린 화면: 오후 4~10시 사이면 창은 어제 22시~오늘 22시', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.start, DateTime(2026, 8, 9, 22));
      expect(w.end, DateTime(2026, 8, 10, 22));
    });

    test('오전이면 프레임이 6시간 뒤로 물러나 있다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 8, 23));
      expect(w.start, DateTime(2026, 8, 9, 10));
      expect(w.end, DateTime(2026, 8, 10, 10));
    });

    test('자정 직전이면 창 끝이 다음 날로 넘어간다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 23, 30));
      expect(w.end, DateTime(2026, 8, 11, 4));
      expect(w.start, DateTime(2026, 8, 10, 4));
    });

    test('새벽은 같은 날 04시가 창 끝', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 2, 5));
      expect(w.end, DateTime(2026, 8, 10, 4));
    });

    test('눈금에 정확히 걸치면 다음 눈금으로 넘어간다 — 폭 0인 창을 만들지 않는다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 10));
      expect(w.end, DateTime(2026, 8, 10, 16));
    });

    test('창은 언제나 24시간이다', () {
      for (var h = 0; h < 24; h++) {
        final w = StatsWindow.of(DateTime(2026, 8, 10, h, 17));
        expect(w.end.difference(w.start), const Duration(hours: 24),
            reason: '$h시');
      }
    });
  });

  group('회색 밴드 — 아직 안 지난 시간', () {
    test('눈금을 갓 넘겼으면 6시간이 통째로 남는다 (= 폭 25%)', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 1));
      expect(w.elapsed, closeTo(0.75, 0.001));
    });

    test('눈금 직전이면 밴드가 거의 없다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 21, 59));
      expect(w.elapsed, closeTo(1.0, 0.001));
    });

    test('Figma 실측 밴드 폭(약 22%)이 나오는 시각이 존재한다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(1 - w.elapsed, closeTo(0.22, 0.01));
    });

    test('0~1을 벗어나지 않는다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.elapsed, inInclusiveRange(0, 1));
    });
  });

  group('X축 눈금', () {
    test('창 시작부터 6시간 간격 4개 — 오른쪽 끝 눈금은 그리지 않는다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.ticks.map((t) => t.at.hour).toList(), [22, 4, 10, 16]);
    });

    test('Figma 라벨과 같은 순서로 나온다', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 40));
      final labels = w.ticks
          .map((t) => '${t.isAm ? "오전" : "오후"} ${t.hour12}시')
          .toList();
      expect(labels, ['오후 10시', '오전 4시', '오전 10시', '오후 4시']);
    });

    test('위치는 0 / 0.25 / 0.5 / 0.75', () {
      final w = StatsWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.ticks.map((t) => t.position).toList(),
          [closeTo(0, 1e-9), closeTo(.25, 1e-9), closeTo(.5, 1e-9), closeTo(.75, 1e-9)]);
    });

    test('눈금은 언제나 6시간 간격을 지킨다', () {
      for (var h = 0; h < 24; h++) {
        final ticks = StatsWindow.of(DateTime(2026, 8, 10, h, 41)).ticks;
        for (var i = 1; i < ticks.length; i++) {
          expect(ticks[i].at.difference(ticks[i - 1].at),
              const Duration(hours: 6), reason: '$h시');
        }
      }
    });
  });
}
