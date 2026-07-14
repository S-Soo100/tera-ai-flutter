import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/cage_activity.dart';

void main() {
  group('activityRangeBounds (오전 7시 기준 하루 경계)', () {
    test('오전 7시 이후 → 오늘은 당일 07:00 ~ 익일 07:00', () {
      final now = DateTime(2026, 7, 3, 10, 30);

      final today = activityRangeBounds(ActivityRange.today, now);
      expect(today.start, DateTime(2026, 7, 3, 7));
      expect(today.end, DateTime(2026, 7, 4, 7));

      final yst = activityRangeBounds(ActivityRange.yesterday, now);
      expect(yst.start, DateTime(2026, 7, 2, 7));
      expect(yst.end, DateTime(2026, 7, 3, 7));
    });

    test('오전 7시 이전 → 오늘은 전일 07:00 ~ 당일 07:00', () {
      final now = DateTime(2026, 7, 3, 5);

      final today = activityRangeBounds(ActivityRange.today, now);
      expect(today.start, DateTime(2026, 7, 2, 7));
      expect(today.end, DateTime(2026, 7, 3, 7));

      final yst = activityRangeBounds(ActivityRange.yesterday, now);
      expect(yst.start, DateTime(2026, 7, 1, 7));
      expect(yst.end, DateTime(2026, 7, 2, 7));
    });

    test('정확히 07:00 → 당일 시작 (경계는 오늘에 포함)', () {
      final now = DateTime(2026, 7, 3, 7);

      final today = activityRangeBounds(ActivityRange.today, now);
      expect(today.start, DateTime(2026, 7, 3, 7));
      expect(today.end, DateTime(2026, 7, 4, 7));
    });

    test('06:59:59 → 아직 어제 (07:00 직전)', () {
      final now = DateTime(2026, 7, 3, 6, 59, 59);

      final today = activityRangeBounds(ActivityRange.today, now);
      expect(today.start, DateTime(2026, 7, 2, 7));
      expect(today.end, DateTime(2026, 7, 3, 7));
    });

    test('월 경계 → 7/1 새벽의 "오늘"은 6/30 07:00 시작, "어제"는 6/29~6/30', () {
      final now = DateTime(2026, 7, 1, 3);

      final today = activityRangeBounds(ActivityRange.today, now);
      expect(today.start, DateTime(2026, 6, 30, 7));
      expect(today.end, DateTime(2026, 7, 1, 7));

      final yst = activityRangeBounds(ActivityRange.yesterday, now);
      expect(yst.start, DateTime(2026, 6, 29, 7));
      expect(yst.end, DateTime(2026, 6, 30, 7));
    });

    test('연 경계 → 1/1 새벽의 "오늘"은 전년 12/31 07:00 시작', () {
      final now = DateTime(2026, 1, 1, 2);

      final today = activityRangeBounds(ActivityRange.today, now);
      expect(today.start, DateTime(2025, 12, 31, 7));
      expect(today.end, DateTime(2026, 1, 1, 7));
    });
  });

  group('bucketMotionSecondsByHour (07시 기준 24시간 버킷)', () {
    final from = DateTime(2026, 7, 3, 7); // 하루 시작 07:00

    test('빈 입력 → 24개 0', () {
      final b = bucketMotionSecondsByHour(const [], from);
      expect(b.length, 24);
      expect(b.every((v) => v == 0), isTrue);
    });

    test('시작 시각이 속한 버킷에 귀속 (07:30→0, 08:10→1, 익일 06:00→23)', () {
      final b = bucketMotionSecondsByHour([
        (startedAt: DateTime(2026, 7, 3, 7, 30), durationSec: 60.0),
        (startedAt: DateTime(2026, 7, 3, 8, 10), durationSec: 30.0),
        (startedAt: DateTime(2026, 7, 4, 6, 0), durationSec: 45.0),
      ], from);
      expect(b[0], 60);
      expect(b[1], 30);
      expect(b[23], 45);
    });

    test('같은 버킷 여러 클립 → 합산 (09시대 = index 2)', () {
      final b = bucketMotionSecondsByHour([
        (startedAt: DateTime(2026, 7, 3, 9, 5), durationSec: 12.0),
        (startedAt: DateTime(2026, 7, 3, 9, 55), durationSec: 20.0),
      ], from);
      expect(b[2], 32);
    });

    test('범위 밖(시작 전 / 정확히 24h / 24h 초과)은 무시', () {
      final b = bucketMotionSecondsByHour([
        (startedAt: DateTime(2026, 7, 3, 6, 59), durationSec: 100.0), // from 이전
        (
          startedAt: DateTime(2026, 7, 4, 7, 0),
          durationSec: 100.0
        ), // 정확히 24h 후
        (startedAt: DateTime(2026, 7, 4, 8, 0), durationSec: 100.0), // 24h 초과
      ], from);
      expect(b.every((v) => v == 0), isTrue);
    });

    test('초는 반올림 (20.8 → 21)', () {
      final b = bucketMotionSecondsByHour([
        (startedAt: DateTime(2026, 7, 3, 7, 0), durationSec: 10.4),
        (startedAt: DateTime(2026, 7, 3, 7, 30), durationSec: 10.4),
      ], from);
      expect(b[0], 21);
    });
  });

  group('activityDurationSeconds', () {
    test('유효한 effective 값이 있으면 raw보다 우선한다', () {
      expect(
        activityDurationSeconds({
          'effective_activity_sec': 0,
          'raw_duration_sec': 31.8,
        }),
        0,
      );
    });

    test('effective가 null이면 view의 raw 값으로 fail-open한다', () {
      expect(
        activityDurationSeconds({
          'effective_activity_sec': null,
          'raw_duration_sec': 31.8,
        }),
        31.8,
      );
    });

    test('raw query row의 duration_sec도 읽는다', () {
      expect(activityDurationSeconds({'duration_sec': 12.5}), 12.5);
    });

    test('음수·NaN effective는 raw 값으로 fail-open한다', () {
      expect(
        activityDurationSeconds({
          'effective_activity_sec': -1,
          'raw_duration_sec': 20,
        }),
        20,
      );
      expect(
        activityDurationSeconds({
          'effective_activity_sec': double.nan,
          'raw_duration_sec': 20,
        }),
        20,
      );
    });

    test('유효한 초가 하나도 없으면 오류로 드러낸다', () {
      expect(
        () => activityDurationSeconds(const {}),
        throwsFormatException,
      );
    });

    test('앱은 decision 이름을 재해석하지 않고 view 계산값만 사용한다', () {
      final rows = [
        {
          'activity_decision': 'active',
          'effective_activity_sec': 30,
          'raw_duration_sec': 30,
        },
        {
          'activity_decision': 'exclude_static',
          'effective_activity_sec': 0,
          'raw_duration_sec': 30,
        },
        {
          'activity_decision': 'exclude_absent',
          'effective_activity_sec': 30,
          'raw_duration_sec': 30,
        },
        {
          'activity_decision': 'unknown',
          'effective_activity_sec': 30,
          'raw_duration_sec': 30,
        },
        {
          'activity_decision': 'pending',
          'effective_activity_sec': 30,
          'raw_duration_sec': 30,
        },
      ];

      expect(rows.map(activityDurationSeconds), [30, 0, 30, 30, 30]);
    });
  });
}
