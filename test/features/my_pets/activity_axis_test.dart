import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/domain/activity_axis.dart';

void main() {
  const minute = 60.0;
  const hour = 3600.0;

  test('봉우리를 담는 가장 작은 눈금을 고른다', () {
    expect(ActivityAxis.forPeak(2.5 * hour).maxSeconds, 3 * hour);
    expect(ActivityAxis.forPeak(3 * hour).maxSeconds, 3 * hour);
    expect(ActivityAxis.forPeak(3 * hour + 1).maxSeconds, 6 * hour);
  });

  test('3시간에 한참 못 미치면 축도 같이 줄어든다', () {
    // 하루 10분이 3시간 축에서 5% 높이로 눌려 보이던 문제(2026-09-21 신고).
    expect(ActivityAxis.forPeak(10 * minute).maxSeconds, 12 * minute);
    expect(ActivityAxis.forPeak(4 * minute).maxSeconds, 6 * minute);
    expect(ActivityAxis.forPeak(25 * minute).maxSeconds, 30 * minute);
    expect(ActivityAxis.forPeak(50 * minute).maxSeconds, hour);
  });

  test('눈금은 항상 7개, 0에서 시작한다', () {
    for (final peak in [30.0, 10 * minute, 2 * hour, 20 * hour]) {
      final axis = ActivityAxis.forPeak(peak);
      expect(axis.ticks.length, 7, reason: '$peak');
      expect(axis.ticks.first, 0);
      expect(axis.ticks.last, axis.maxSeconds);
    }
  });

  test('한 시간 반 이하는 분, 그 위는 시간으로 읽는다', () {
    expect(ActivityAxis.forPeak(10 * minute).inMinutes, isTrue);
    expect(ActivityAxis.forPeak(80 * minute).inMinutes, isTrue);
    expect(ActivityAxis.forPeak(2 * hour).inMinutes, isFalse);
  });

  test('분 눈금은 정수로 떨어진다', () {
    for (final peak in [30.0, 5 * minute, 10 * minute, 40 * minute, 80 * minute]) {
      final axis = ActivityAxis.forPeak(peak);
      for (final tick in axis.ticks) {
        expect(tick % 60, 0, reason: 'peak=$peak tick=$tick');
      }
    }
  });

  test('측정값이 없으면 한 시간 축을 쓴다', () {
    expect(ActivityAxis.forPeak(0).maxSeconds, hour);
  });

  test('아주 긴 하루도 잘리지 않는다', () {
    final axis = ActivityAxis.forPeak(23 * hour);
    expect(axis.maxSeconds, greaterThanOrEqualTo(23 * hour));
  });
}
