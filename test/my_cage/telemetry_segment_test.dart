import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';

/// 특정 시각·sample_count의 최소 버킷 생성. 온습도 값은 이 테스트에 무관.
TelemetryBucket _bucketAt(DateTime t, {int sampleCount = 600}) {
  return TelemetryBucket(
    bucket: t,
    sampleCount: sampleCount,
    tAvg: 26,
    tMin: 25,
    tMax: 27,
    hAvg: 55,
    hMin: 50,
    hMax: 60,
  );
}

void main() {
  group('TelemetryBucket.isPartial', () {
    test('sample_count 299 → partial(true)', () {
      expect(_bucketAt(DateTime.utc(2026), sampleCount: 299).isPartial, isTrue);
    });
    test('sample_count 300 → not partial(false)', () {
      expect(
        _bucketAt(DateTime.utc(2026), sampleCount: 300).isPartial,
        isFalse,
      );
    });
    test('sample_count 600 → not partial(false)', () {
      expect(
        _bucketAt(DateTime.utc(2026), sampleCount: 600).isPartial,
        isFalse,
      );
    });
  });
}
