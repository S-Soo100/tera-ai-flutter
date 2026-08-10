import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/dev/presentation/chart_lab_fixtures.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';
import 'package:vivnanaut/shared/domain/env_chart_data.dart';

final _window = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));

EnvChartData _data(ChartShape s) => EnvChartData.from(
      buildLabBuckets(shape: s, window: _window),
      from: _window.start,
      to: _window.end,
    );

void main() {
  group('검토용 데이터', () {
    test('미도래 구간에는 값을 만들지 않는다 — 회색 밴드 위로 선이 지나가면 안 된다', () {
      for (final s in ChartShape.values) {
        for (final b in buildLabBuckets(shape: s, window: _window)) {
          expect(b.bucket.isAfter(_window.now), isFalse, reason: '$s');
        }
      }
    });

    test('모양마다 실제로 다른 축이 나온다 — 같은 그림이면 검토할 게 없다', () {
      final narrow = _data(ChartShape.flat).tempAxis!;
      final wide = _data(ChartShape.wide).tempAxis!;
      expect(narrow.span, lessThan(wide.span));
      expect(narrow.ticks, hasLength(6));
      expect(wide.ticks, hasLength(6));
    });

    test('중간 결측은 선을 끊되 0으로 내리꽂지 않는다', () {
      final d = _data(ChartShape.gap);
      final full = _data(ChartShape.daily);
      expect(d.tempPoints.length, lessThan(full.tempPoints.length));
      expect(d.tempAxis!.min, greaterThan(0));
    });

    test('온도만 모양은 습도 축을 만들지 않는다', () {
      final d = _data(ChartShape.tempOnly);
      expect(d.tempAxis, isNotNull);
      expect(d.humidAxis, isNull);
    });

    test('데이터 없음은 정말로 비어 있다', () {
      expect(_data(ChartShape.empty).hasData, isFalse);
    });
  });

  group('검토용 마커', () {
    test('전부 창 안에 들어간다 — 밖이면 그려지지 않아 검토가 안 된다', () {
      for (final m in buildLabMarkers(_window)) {
        expect(m.positionIn(start: _window.start, end: _window.end), isNotNull);
      }
    });

    test('Figma에 그림이 없는 종류(히터)도 하나 끼워둔다', () {
      final kinds = buildLabMarkers(_window).map((m) => m.kind).toSet();
      expect(kinds.length, greaterThanOrEqualTo(3));
    });
  });
}
