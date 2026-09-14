import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';

void main() {
  test('오늘 최신 센서만 표시하고 오래된 값/다른 기기/센티넬을 배제한다', () {
    final now = DateTime.utc(2026, 9, 14, 0, 0, 10);
    TelemetryReading reading(
            {String id = 'd', int age = 3, double t = 28, bool ok = true}) =>
        TelemetryReading.fromJson({
          'device_id': id,
          'ts': now.subtract(Duration(seconds: age)).toIso8601String(),
          't_a': t,
          'h_a': 60,
          'a_ok': ok
        });
    EnvRealtimeValues value(TelemetryReading r, {bool stale = false}) =>
        realtimeEnvironment(r,
            deviceId: 'd',
            now: now,
            freshness: const Duration(seconds: 12),
            stale: stale);
    expect(value(reading()), (temperature: 28.0, humidity: 60.0));
    expect(value(reading(age: 13)).temperature, isNull);
    expect(value(reading(age: -1)).temperature, isNull);
    expect(value(reading(id: 'other')).temperature, isNull);
    expect(value(reading(ok: false)).humidity, isNull);
    expect(value(reading(), stale: true).temperature, isNull);
    expect(value(reading(t: 0)), (temperature: null, humidity: 60.0));
  });
  TelemetryBucket bucket(double t, double h, int? tc, int? hc) =>
      TelemetryBucket(
          bucket: DateTime(2026),
          sampleCount: 100,
          tAvg: t,
          tMin: t,
          tMax: t,
          hAvg: h,
          hMin: h,
          hMax: h,
          tValidCount: tc,
          hValidCount: hc);
  test('일평균 provider는 지표별 유효 개수로 별도 가중한다', () async {
    final container = ProviderContainer(overrides: [
      envDayBucketsProvider.overrideWith(
          (ref) async => [bucket(20, 40, 1, 3), bucket(30, 60, 3, 1)])
    ]);
    addTearDown(container.dispose);
    final result = await container.read(envDailyAverageProvider.future);
    expect(
        result, (temperature: 27.5, humidity: 45.0, countUnavailable: false));
  });
  test('count 미지원은 raw sampleCount로 대체하거나 일부 평균으로 숨기지 않는다', () async {
    final container = ProviderContainer(overrides: [
      envDayBucketsProvider.overrideWith(
          (ref) async => [bucket(20, 40, null, 3), bucket(30, 60, 3, 1)])
    ]);
    addTearDown(container.dispose);
    final result = await container.read(envDailyAverageProvider.future);
    expect(result, (temperature: null, humidity: 45.0, countUnavailable: true));
  });
}
