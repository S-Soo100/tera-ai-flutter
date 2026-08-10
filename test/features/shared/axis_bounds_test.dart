import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/axis_bounds.dart';

void main() {
  group('눈금 개수는 고정 — 격자선 6줄과 맞아야 한다', () {
    test('좁은 데이터도 6개', () {
      expect(AxisBounds.forValues([28.0, 29.0])!.ticks, hasLength(6));
    });

    test('넓은 데이터도 6개 — 개수 대신 칸 크기를 키운다', () {
      final a = AxisBounds.forValues([5.0, 95.0])!;
      expect(a.ticks, hasLength(6));
      expect(a.step, greaterThan(1));
    });

    test('값이 하나뿐이어도 6개, 폭은 0이 아니다', () {
      final a = AxisBounds.forValues([31.3])!;
      expect(a.ticks, hasLength(6));
      expect(a.span, greaterThan(0));
    });

    test('어떤 데이터를 넣어도 6개를 지킨다', () {
      for (final pair in [
        [1.0, 2.0],
        [20.0, 35.0],
        [58.0, 72.0],
        [0.5, 0.9],
        [100.0, 999.0],
        [23.5, 23.6],
      ]) {
        final a = AxisBounds.forValues(pair)!;
        expect(a.ticks, hasLength(6), reason: '$pair');
        expect(a.min, lessThanOrEqualTo(pair.first), reason: '$pair');
        expect(a.max, greaterThanOrEqualTo(pair.last), reason: '$pair');
      }
    });
  });

  group('칸 크기 — 읽을 수 있는 숫자여야 한다', () {
    test('1·2·5 계열만 쓴다 — 3이나 7 단위는 암산이 안 된다', () {
      for (final hi in [2.0, 9.0, 40.0, 60.0, 88.0, 120.0, 700.0, 3000.0]) {
        final a = AxisBounds.forValues([1.0, hi])!;
        final mantissa = a.step / _pow10((a.step).abs());
        expect([1.0, 2.0, 5.0], contains(closeTo(mantissa, 1e-9)),
            reason: 'hi=$hi step=${a.step}');
      }
    });

    test('기본 하한은 1 — 정수 라벨이 반복되면 안 된다', () {
      final a = AxisBounds.forValues([28.1, 28.4])!;
      expect(a.step, greaterThanOrEqualTo(1));
      final labels = a.ticks.map((v) => v.toStringAsFixed(0)).toSet();
      expect(labels, hasLength(6));
    });

    test('하한을 올리면 그보다 작은 칸은 안 나온다', () {
      final a = AxisBounds.forValues([28.0, 29.0], minStep: 5)!;
      expect(a.step, greaterThanOrEqualTo(5));
      expect(a.ticks, hasLength(6));
    });

    test('눈금은 min부터 step 간격으로 균등하다', () {
      final a = AxisBounds.forValues([22.0, 37.0])!;
      final t = a.ticks;
      expect(t.first, a.min);
      expect(t.last, closeTo(a.max, 1e-9));
      for (var i = 1; i < t.length; i++) {
        expect(t[i] - t[i - 1], closeTo(a.step, 1e-9));
      }
    });
  });

  group('데이터 배치', () {
    test('좁은 데이터가 축 한쪽 모서리에 붙지 않는다', () {
      final a = AxisBounds.forValues([31.0, 32.0])!;
      expect(a.min, lessThan(31));
      expect(a.max, greaterThan(32));
    });

    test('축이 데이터보다 지나치게 넓어지지 않는다 — 곡선이 납작해진다', () {
      // 23.5~26℃(폭 2.5)가 25도짜리 축에 그려지면 직선처럼 보인다.
      final a = AxisBounds.forValues([23.5, 26.0])!;
      expect(a.span, lessThanOrEqualTo(10));
    });

    test('normalize는 min→0, max→1', () {
      final a = AxisBounds.forValues([20.0, 30.0])!;
      expect(a.normalize(a.min), 0);
      expect(a.normalize(a.max), 1);
    });
  });

  group('센서 오프라인 센티넬(0) 제거', () {
    test('0은 축 계산에서 빠진다', () {
      final a = AxisBounds.forValues([0, 24, 26, 0])!;
      expect(a.min, greaterThan(0));
      expect(a.min, lessThanOrEqualTo(24));
    });

    test('전부 0이면 축을 만들지 않는다', () {
      expect(AxisBounds.forValues([0, 0]), isNull);
    });

    test('음수도 유효 값이 아니다', () {
      expect(AxisBounds.forValues([-5, -1]), isNull);
    });

    test('빈 목록이면 null — 가짜 축을 그리지 않는다', () {
      expect(AxisBounds.forValues(const []), isNull);
    });
  });
}

/// [v]보다 작거나 같은 가장 큰 10의 거듭제곱.
double _pow10(double v) {
  var p = 1.0;
  while (p * 10 <= v + 1e-9) {
    p *= 10;
  }
  while (p > v + 1e-9) {
    p /= 10;
  }
  return p;
}
