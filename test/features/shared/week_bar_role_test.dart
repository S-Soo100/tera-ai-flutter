import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/week_range.dart';
import 'package:vivnanaut/shared/domain/week_bar_role.dart';

void main() {
  DayMinMax row(int day, double? min, double? max) =>
      DayMinMax(day: DateTime(2026, 9, day), min: min, max: max);
  test('최고와 최저 동률을 모든 해당 요일에 표시한다', () {
    expect(
        classifyWeekBars([
          row(7, 20, 25),
          row(8, 20, 26),
          row(9, 22, 30),
          row(10, 23, 30),
          row(11, 23, 27),
          row(12, null, null),
        ]),
        [
          WeekBarRole.minimum,
          WeekBarRole.minimum,
          WeekBarRole.maximum,
          WeekBarRole.maximum,
          WeekBarRole.neutral,
          WeekBarRole.empty
        ]);
  });
  test('최고와 최저가 같은 요일이면 최고를 우선한다', () {
    expect(classifyWeekBars([row(7, 10, 30), row(8, 20, 25)]),
        [WeekBarRole.maximum, WeekBarRole.neutral]);
  });
  test('단일 유효요일과 모든 동일 범위는 중립이다', () {
    expect(classifyWeekBars([row(7, 20, 30), row(8, null, null)]),
        [WeekBarRole.neutral, WeekBarRole.empty]);
    expect(classifyWeekBars([row(7, 20, 30), row(8, 20, 30)]),
        [WeekBarRole.neutral, WeekBarRole.neutral]);
  });
  test('보이는 소수 한 자리 동률과 비정상 값 제외', () {
    expect(
        classifyWeekBars([
          row(7, 20.01, 25),
          row(8, 20.04, 27),
          row(9, 22, 30),
          row(10, double.nan, double.infinity)
        ]),
        [
          WeekBarRole.minimum,
          WeekBarRole.minimum,
          WeekBarRole.maximum,
          WeekBarRole.empty
        ]);
  });
}
