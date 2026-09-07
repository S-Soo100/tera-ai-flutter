import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/fan_timer_duration.dart';

void main() {
  test('payload는 duration_ms(밀리초)를 담는다', () {
    expect(FanTimerDuration.m10.payload, {'duration_ms': 600000});
    expect(FanTimerDuration.m30.payload, {'duration_ms': 1800000});
    expect(FanTimerDuration.h1.payload, {'duration_ms': 3600000});
    expect(FanTimerDuration.h2.payload, {'duration_ms': 7200000});
  });

  test('계약 상한 2h(7,200,000ms)를 넘는 값이 없다', () {
    for (final d in FanTimerDuration.values) {
      expect(d.payload['duration_ms'], lessThanOrEqualTo(7200000));
    }
  });

  test('라벨 키 — 분 단위와 시간 단위가 갈린다', () {
    expect(FanTimerDuration.m10.labelKey, 'home_timer_10m');
    expect(FanTimerDuration.m30.labelKey, 'home_timer_30m');
    expect(FanTimerDuration.h1.labelKey, 'home_timer_1h');
    expect(FanTimerDuration.h2.labelKey, 'home_timer_2h');
  });
}
