import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/stats/domain/axis_bounds.dart';

void main() {
  group('AxisBounds.forValues — 눈금 단위로 스냅', () {
    test('범위를 step 배수로 넓힌다 — 선이 축 밖으로 나가면 안 된다', () {
      final b = AxisBounds.forValues([23.5, 26.0, 24.1], step: 5)!;
      expect(b.min, 20);
      expect(b.max, 30);
    });

    test('경계에 딱 맞으면 그대로 둔다', () {
      final b = AxisBounds.forValues([20, 35], step: 5)!;
      expect(b.min, 20);
      expect(b.max, 35);
    });

    test('ticks는 step 간격으로 min~max 전부', () {
      final b = AxisBounds.forValues([21, 33], step: 5)!;
      expect(b.min, 20);
      expect(b.max, 35);
      expect(b.ticks, [20, 25, 30, 35]);
    });

    test('값이 하나뿐이면 위아래로 최소 1칸씩 벌린다 — 납작한 축을 만들지 않는다', () {
      final b = AxisBounds.forValues([24], step: 5)!;
      expect(b.min, 20);
      expect(b.max, 25);
      expect(b.span, greaterThan(0));
    });

    test('값이 정확히 경계 하나면 그래도 1칸 폭을 확보한다', () {
      final b = AxisBounds.forValues([25], step: 5)!;
      expect(b.max - b.min, greaterThanOrEqualTo(5));
      expect(b.min, lessThanOrEqualTo(25));
      expect(b.max, greaterThanOrEqualTo(25));
    });

    test('빈 목록이면 null — 데이터 없이 가짜 축을 그리지 않는다', () {
      expect(AxisBounds.forValues(const [], step: 5), isNull);
    });

    test('0 이하 값은 버린다 — telemetry_30m의 0은 센서 오프라인 센티넬이다', () {
      // 0을 넣으면 축이 0까지 늘어나 실제 곡선이 납작해진다.
      final b = AxisBounds.forValues([0, 24, 26, 0], step: 5);
      expect(b!.min, 20);
      expect(b.max, 30);
    });

    test('전부 0이면 null', () {
      expect(AxisBounds.forValues([0, 0], step: 5), isNull);
    });

    test('음수도 버린다', () {
      expect(AxisBounds.forValues([-5, -1], step: 5), isNull);
    });

    test('습도 예시 — 58~72%는 55~75로', () {
      final b = AxisBounds.forValues([58, 72, 63], step: 5);
      expect(b!.min, 55);
      expect(b.max, 75);
      expect(b.ticks, [55, 60, 65, 70, 75]);
    });

    test('normalize — 값을 0~1 비율로', () {
      final b = AxisBounds.forValues([20, 30], step: 5)!;
      expect(b.normalize(20), 0);
      expect(b.normalize(30), 1);
      expect(b.normalize(25), closeTo(0.5, 1e-9));
    });
  });
}
