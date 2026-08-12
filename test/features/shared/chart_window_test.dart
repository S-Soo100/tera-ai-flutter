import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';

void main() {
  group('창 끝 — 다음 6시간 눈금', () {
    test('Figma가 그린 화면: 오후 4~10시 사이면 창은 어제 22시~오늘 22시', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.start, DateTime(2026, 8, 9, 22));
      expect(w.end, DateTime(2026, 8, 10, 22));
    });

    test('오전이면 프레임이 6시간 뒤로 물러나 있다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 8, 23));
      expect(w.start, DateTime(2026, 8, 9, 10));
      expect(w.end, DateTime(2026, 8, 10, 10));
    });

    test('자정 직전이면 창 끝이 다음 날로 넘어간다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 23, 30));
      expect(w.end, DateTime(2026, 8, 11, 4));
      expect(w.start, DateTime(2026, 8, 10, 4));
    });

    test('새벽은 같은 날 04시가 창 끝', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 2, 5));
      expect(w.end, DateTime(2026, 8, 10, 4));
    });

    test('눈금에 정확히 걸치면 다음 눈금으로 넘어간다 — 폭 0인 창을 만들지 않는다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 10));
      expect(w.end, DateTime(2026, 8, 10, 16));
    });

    test('창은 언제나 24시간이다', () {
      for (var h = 0; h < 24; h++) {
        final w = ChartWindow.of(DateTime(2026, 8, 10, h, 17));
        expect(w.end.difference(w.start), const Duration(hours: 24),
            reason: '$h시');
      }
    });
  });

  group('회색 밴드 — 아직 안 지난 시간', () {
    test('눈금을 갓 넘겼으면 6시간이 통째로 남는다 (= 폭 25%)', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 1));
      expect(w.elapsed, closeTo(0.75, 0.001));
    });

    test('눈금 직전이면 밴드가 거의 없다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 21, 59));
      expect(w.elapsed, closeTo(1.0, 0.001));
    });

    test('Figma 실측 밴드 폭(약 22%)이 나오는 시각이 존재한다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(1 - w.elapsed, closeTo(0.22, 0.01));
    });

    test('0~1을 벗어나지 않는다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.elapsed, inInclusiveRange(0, 1));
    });
  });

  group('X축 눈금', () {
    test('창 시작부터 6시간 간격 4개 — 오른쪽 끝 눈금은 그리지 않는다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.ticks.map((t) => t.at.hour).toList(), [22, 4, 10, 16]);
    });

    test('Figma 라벨과 같은 순서로 나온다', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));
      final labels = w.ticks
          .map((t) => '${t.isAm ? "오전" : "오후"} ${t.hour12}시')
          .toList();
      expect(labels, ['오후 10시', '오전 4시', '오전 10시', '오후 4시']);
    });

    test('위치는 0 / 0.25 / 0.5 / 0.75', () {
      final w = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));
      expect(w.ticks.map((t) => t.position).toList(),
          [closeTo(0, 1e-9), closeTo(.25, 1e-9), closeTo(.5, 1e-9), closeTo(.75, 1e-9)]);
    });

    test('눈금은 언제나 6시간 간격을 지킨다', () {
      for (var h = 0; h < 24; h++) {
        final ticks = ChartWindow.of(DateTime(2026, 8, 10, h, 41)).ticks;
        for (var i = 1; i < ticks.length; i++) {
          expect(ticks[i].at.difference(ticks[i - 1].at),
              const Duration(hours: 6), reason: '$h시');
        }
      }
    });
  });


  group('주간 창 — 하루 경계(07:00) 7칸', () {
    test('창 끝은 지금 이후 첫 07시, 시작은 그 7일 전', () {
      // 07시 이후면 창 끝은 내일 07시. 오늘 몫이 미도래 밴드가 된다.
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 15, 43));
      expect(w.end, DateTime(2026, 8, 13, 7));
      expect(w.start, DateTime(2026, 8, 6, 7));
    });

    test('07시 이전이면 오늘 07시가 창 끝 — 하루가 아직 안 시작했다', () {
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 3, 10));
      expect(w.end, DateTime(2026, 8, 12, 7));
      expect(w.start, DateTime(2026, 8, 5, 7));
    });

    test('07시 정각은 다음 날로 넘긴다 — 폭 0인 밴드를 만들지 않는다', () {
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 7));
      expect(w.end, DateTime(2026, 8, 13, 7));
    });

    test('일간과 같은 07:00 경계를 쓴다 — 두 화면이 다른 하루를 말하면 안 된다', () {
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 15));
      for (final t in w.ticks) {
        expect(t.at.hour, 7, reason: '${t.at}');
      }
    });

    test('눈금 7개, 오른쪽 끝은 뺀다', () {
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 15));
      expect(w.ticks, hasLength(7));
      expect(w.ticks.first.at, DateTime(2026, 8, 6, 7));
      expect(w.ticks.last.at, DateTime(2026, 8, 12, 7));
      expect(w.ticks.map((t) => t.at), isNot(contains(w.end)));
    });

    test('눈금 위치는 0에서 시작해 고르게 벌어진다', () {
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 15));
      expect(w.ticks.first.position, closeTo(0, 0.0001));
      expect(w.ticks[1].position, closeTo(1 / 7, 0.0001));
    });

    test('날짜로 읽는다 — 주간에 오전/오후 시각 라벨은 뜻이 없다', () {
      expect(ChartWindow.weekly(DateTime(2026, 8, 12, 15)).format,
          ChartTickFormat.date);
      expect(ChartWindow.of(DateTime(2026, 8, 12, 15)).format,
          ChartTickFormat.hour);
    });

    test('미도래 밴드는 오늘 지나온 만큼만 남긴다', () {
      // 8/12 15시 → 창은 8/6 07시~8/13 07시(7일). 지난 건 6일 8시간.
      final w = ChartWindow.weekly(DateTime(2026, 8, 12, 15));
      expect(w.elapsed, closeTo((6 * 24 + 8) / (7 * 24), 0.001));
    });
  });
}
