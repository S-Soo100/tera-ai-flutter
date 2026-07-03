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
}
