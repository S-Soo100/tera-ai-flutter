import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';
import 'package:tera_ai/features/my_cage/presentation/widgets/telemetry_history_chart.dart';

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
  group('segmentByGap', () {
    test('빈 리스트 → 빈 리스트', () {
      expect(segmentByGap(const []), isEmpty);
    });

    test('연속 30분 간격 5개 → 세그먼트 1개(길이 5)', () {
      final base = DateTime.utc(2026, 7, 7, 0, 0);
      final buckets = List.generate(
        5,
        (i) => _bucketAt(base.add(Duration(minutes: 30 * i))),
      );
      final segments = segmentByGap(buckets);
      expect(segments, hasLength(1));
      expect(segments.first, hasLength(5));
    });

    test('중간 2시간 gap → 세그먼트 2개로 분할', () {
      final base = DateTime.utc(2026, 7, 7, 0, 0);
      final buckets = [
        _bucketAt(base), // 00:00
        _bucketAt(base.add(const Duration(minutes: 30))), // 00:30
        // 2시간 gap (선을 끊어야 함)
        _bucketAt(base.add(const Duration(hours: 2, minutes: 30))), // 02:30
        _bucketAt(base.add(const Duration(hours: 3))), // 03:00
      ];
      final segments = segmentByGap(buckets);
      expect(segments, hasLength(2));
      expect(segments[0], hasLength(2));
      expect(segments[1], hasLength(2));
    });

    test('45분 경계: threshold와 같으면 이어지고, 초과하면 끊긴다', () {
      final base = DateTime.utc(2026, 7, 7, 0, 0);
      // 45분(== threshold) → 한 세그먼트
      final joined = segmentByGap([
        _bucketAt(base),
        _bucketAt(base.add(const Duration(minutes: 45))),
      ]);
      expect(joined, hasLength(1));
      // 46분(> threshold) → 두 세그먼트
      final split = segmentByGap([
        _bucketAt(base),
        _bucketAt(base.add(const Duration(minutes: 46))),
      ]);
      expect(split, hasLength(2));
    });

    test('단일 버킷 → 세그먼트 1개(길이 1)', () {
      final segments = segmentByGap([_bucketAt(DateTime.utc(2026, 7, 7))]);
      expect(segments, hasLength(1));
      expect(segments.first, hasLength(1));
    });
  });

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
