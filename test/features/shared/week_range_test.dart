import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/shared/domain/week_range.dart';

TelemetryBucket bucket(
  DateTime at, {
  double? tMin,
  double? tMax,
  double? hMin,
  double? hMax,
}) {
  return TelemetryBucket(
    bucket: at,
    sampleCount: 600,
    tAvg: tMin,
    tMin: tMin,
    tMax: tMax,
    hAvg: hMin,
    hMin: hMin,
    hMax: hMax,
  );
}

void main() {
  group('WeekRange.containing', () {
    // 2026-08-31은 월요일이다.
    test('수요일 → 그 주 월요일', () {
      final w = WeekRange.containing(DateTime(2026, 9, 2, 15, 30));
      expect(w.monday, DateTime(2026, 8, 31));
    });

    test('월요일 자신 → 같은 날', () {
      final w = WeekRange.containing(DateTime(2026, 8, 31, 3));
      expect(w.monday, DateTime(2026, 8, 31));
    });

    test('일요일 → 지난 월요일 (주는 월요일 시작)', () {
      final w = WeekRange.containing(DateTime(2026, 9, 6, 23, 59));
      expect(w.monday, DateTime(2026, 8, 31));
    });
  });

  group('start / end / previous / next', () {
    final w = WeekRange.containing(DateTime(2026, 9, 2));

    test('start = 월요일 자정, end = 다음 월요일 자정(제외)', () {
      expect(w.start, DateTime(2026, 8, 31));
      expect(w.end, DateTime(2026, 9, 7));
    });

    test('previous / next는 7일씩 달력으로 이동', () {
      expect(w.previous.monday, DateTime(2026, 8, 24));
      expect(w.next.monday, DateTime(2026, 9, 7));
    });

    test('동등성', () {
      expect(w, WeekRange.containing(DateTime(2026, 9, 5)));
      expect(w == w.previous, isFalse);
    });
  });

  group('weekTempRanges', () {
    final week = WeekRange.containing(DateTime(2026, 9, 2));

    test('항상 요일 7칸 고정, 데이터 없는 날은 min/max null', () {
      final rows = weekTempRanges(const [], week);
      expect(rows.length, 7);
      expect(rows.first.day, DateTime(2026, 8, 31));
      expect(rows.last.day, DateTime(2026, 9, 6));
      for (final r in rows) {
        expect(r.min, isNull);
        expect(r.max, isNull);
      }
    });

    test('요일별 min/max 집계', () {
      final rows = weekTempRanges([
        bucket(DateTime(2026, 8, 31, 10), tMin: 24.0, tMax: 29.0),
        bucket(DateTime(2026, 8, 31, 22), tMin: 22.5, tMax: 27.0),
        bucket(DateTime(2026, 9, 2, 3), tMin: 26.0, tMax: 31.5),
      ], week);
      expect(rows[0].min, 22.5);
      expect(rows[0].max, 29.0);
      expect(rows[1].min, isNull); // 화요일 데이터 없음
      expect(rows[2].min, 26.0);
      expect(rows[2].max, 31.5);
    });

    test('0값 센티넬(센서 오프라인)은 버린다', () {
      final rows = weekTempRanges([
        bucket(DateTime(2026, 8, 31, 10), tMin: 0.0, tMax: 0.0),
        bucket(DateTime(2026, 8, 31, 12), tMin: 25.0, tMax: 28.0),
      ], week);
      expect(rows[0].min, 25.0);
      expect(rows[0].max, 28.0);
    });

    test('주 밖 버킷은 무시한다', () {
      final rows = weekTempRanges([
        bucket(DateTime(2026, 8, 30, 23), tMin: 20.0, tMax: 21.0), // 전주 일요일
        bucket(DateTime(2026, 9, 7, 0), tMin: 19.0, tMax: 20.0), // 다음 주 월요일
      ], week);
      for (final r in rows) {
        expect(r.min, isNull);
      }
    });

    test('UTC 버킷 스탬프는 로컬 달력 날짜로 접는다', () {
      // 로컬 8/31 10:00을 UTC로 표기 — 머신 타임존과 무관하게 같은 순간.
      final rows = weekTempRanges([
        bucket(DateTime(2026, 8, 31, 10).toUtc(), tMin: 23.0, tMax: 26.0),
      ], week);
      expect(rows[0].min, 23.0);
      expect(rows[0].max, 26.0);
    });
  });

  group('weekHumidRanges', () {
    final week = WeekRange.containing(DateTime(2026, 9, 2));

    test('습도 min/max 집계 + 센티넬 필터', () {
      final rows = weekHumidRanges([
        bucket(DateTime(2026, 9, 3, 1), hMin: 55.0, hMax: 70.0),
        bucket(DateTime(2026, 9, 3, 5), hMin: 0.0, hMax: 0.0),
        bucket(DateTime(2026, 9, 3, 9), hMin: 48.0, hMax: 62.0),
      ], week);
      expect(rows[3].min, 48.0);
      expect(rows[3].max, 70.0);
      expect(rows[4].min, isNull);
    });
  });
}
