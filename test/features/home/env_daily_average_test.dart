import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/features/home/domain/env_daily_average.dart';

void main() {
  test(
      'missing temperature count does not invent mean or erase valid humidity mean',
      () async {
    final container = ProviderContainer(overrides: [
      envDayBucketsProvider.overrideWith((ref) async => [
            TelemetryBucket(
                bucket: DateTime(2026),
                sampleCount: 100,
                tValidCount: null,
                hValidCount: 4,
                tAvg: 25,
                tMin: 25,
                tMax: 25,
                hAvg: 60,
                hMin: 60,
                hMax: 60)
          ]),
    ]);
    addTearDown(container.dispose);
    final average = await container.read(envDailyAverageProvider.future);
    expect(average.temperature, isNull);
    expect(average.humidity, 60);
    expect(average.countUnavailable, isTrue);
  });
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
