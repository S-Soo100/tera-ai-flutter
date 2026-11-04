import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';

/// 아직 마감되지 않은 30분 칸을 원본 기록으로 채우는 규칙 (2026-11-04 —
/// `telemetry_30m`은 끝난 칸만 있어 오늘 최고·그래프가 최대 30분 넘게 늦었다).
/// 서버 집계와 같은 규칙: `a_ok` + 값>0만 평균·최소·최대·개수에 넣는다.
RawEnvSample _s(String utc, double? t, double? h, {bool ok = true}) =>
    (ts: DateTime.parse(utc), t: t, h: h, ok: ok);

void main() {
  group('TelemetryBucket.aggregate', () {
    test('30분 경계로 나누고 서버와 같은 평균·최소·최대·개수를 낸다', () {
      final buckets = TelemetryBucket.aggregate([
        _s('2026-11-04T03:01:53Z', 27.5, 47.9),
        _s('2026-11-04T03:11:00Z', 28.3, 47.2),
        _s('2026-11-04T03:15:00Z', 27.7, 36.1),
        _s('2026-11-04T03:31:00Z', 26.9, 36.6),
      ]);
      expect(buckets.map((b) => b.bucket),
          [DateTime.utc(2026, 11, 4, 3), DateTime.utc(2026, 11, 4, 3, 30)]);
      final first = buckets.first;
      expect(first.sampleCount, 3);
      expect(first.tValidCount, 3);
      expect(first.hValidCount, 3);
      expect(first.tMin, 27.5);
      expect(first.tMax, 28.3);
      expect(first.tAvg, closeTo((27.5 + 28.3 + 27.7) / 3, 1e-9));
      expect(first.hMin, 36.1);
      expect(first.hMax, 47.9);
    });

    test('센서 오류·0값은 빼고, 행 수에는 센다', () {
      final b = TelemetryBucket.aggregate([
        _s('2026-11-04T03:00:01Z', 0, 0),
        _s('2026-11-04T03:00:04Z', 31, 90, ok: false),
        _s('2026-11-04T03:00:07Z', 26, 50),
      ]).single;
      expect(b.sampleCount, 3);
      expect(b.tValidCount, 1);
      expect(b.tMin, 26);
      expect(b.tMax, 26);
      expect(b.hAvg, 50);
    });

    test('유효 값이 없는 칸은 값 없이(null) 둔다', () {
      final b = TelemetryBucket.aggregate([
        _s('2026-11-04T03:00:01Z', 0, 0),
      ]).single;
      expect(b.tAvg, isNull);
      expect(b.tMax, isNull);
      expect(b.tValidCount, 0);
    });

    test('입력 순서와 무관하게 시간 오름차순', () {
      final buckets = TelemetryBucket.aggregate([
        _s('2026-11-04T03:31:00Z', 26.9, 36.6),
        _s('2026-11-04T03:01:00Z', 27.5, 47.9),
      ]);
      expect(buckets.first.bucket, DateTime.utc(2026, 11, 4, 3));
    });
  });

  group('TelemetryBucket.withOpenTail', () {
    final closed = TelemetryBucket.aggregate([
      _s('2026-11-04T02:31:00Z', 25.9, 48.1),
    ]);

    test('마감된 칸 뒤에 열린 칸을 잇는다', () {
      final tail = TelemetryBucket.aggregate([
        _s('2026-11-04T03:11:00Z', 28.3, 47.2),
      ]);
      final merged = TelemetryBucket.withOpenTail(closed, tail);
      expect(merged.map((b) => b.tMax), [25.9, 28.3]);
    });

    test('같은 칸이 이미 마감됐으면 원본 쪽을 버린다(중복 없음)', () {
      final tail = TelemetryBucket.aggregate([
        _s('2026-11-04T02:59:00Z', 30, 40),
        _s('2026-11-04T03:01:00Z', 27, 47),
      ]);
      final merged = TelemetryBucket.withOpenTail(closed, tail);
      expect(merged.map((b) => b.bucket),
          [DateTime.utc(2026, 11, 4, 2, 30), DateTime.utc(2026, 11, 4, 3)]);
      expect(merged.first.tMax, 25.9);
    });

    test('tailFrom: 마감 칸이 있으면 마지막 칸 끝, 없으면 시작', () {
      final from = DateTime.utc(2026, 11, 3, 15);
      expect(TelemetryBucket.tailFrom(closed, from),
          DateTime.utc(2026, 11, 4, 3));
      expect(TelemetryBucket.tailFrom(const [], from), from);
    });
  });
}
