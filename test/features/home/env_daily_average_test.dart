import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/env_daily_average.dart';

void main() {
  test('불균등 표본은 가중 평균, 센티넬과 무효 표본은 제외', () {
    expect(
        weightedDailyMean([
          (mean: 20.0, validCount: 1),
          (mean: 30.0, validCount: 3),
          (mean: 0.0, validCount: 100)
        ]),
        27.5);
    expect(
        weightedDailyMean(
            [(mean: null, validCount: 0), (mean: double.nan, validCount: 2)]),
        isNull);
    expect(
        weightedDailyMean(
            [(mean: 20.0, validCount: 0), (mean: 30.0, validCount: 2)]),
        30);
  });
}
