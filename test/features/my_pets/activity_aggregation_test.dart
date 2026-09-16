import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';
import 'package:vivanaut/features/my_pets/domain/activity_window.dart';

DateTime utc(String value) => DateTime.parse(value);
ActivityInterval interval(String start, String end, {String camera = 'a'}) =>
    ActivityInterval(cameraId: camera, startUtc: utc(start), endUtc: utc(end));
final day = ActivityWindow.day(2026, 9, 15);
final legacy = ActivityAssignment(cameraId: 'a', origin: ActivityOrigin.legacy);
ActivityDaySummary summarize(List<ActivityInterval> intervals,
        {ActivityWindow? window,
        List<ActivityAssignment>? assignments,
        List<ActivityCoverage> coverage = const []}) =>
    aggregateActivityDay(
        window: window ?? day,
        intervals: intervals,
        assignments: assignments ?? [legacy],
        coverage: coverage,
        now: utc('2026-09-20T00:00:00Z'));

void main() {
  test('KST midnight splits ten seconds on each day on a UTC host', () {
    final values = [interval('2026-09-14T14:59:50Z', '2026-09-14T15:00:10Z')];
    expect(summarize(values).seconds, 10);
    expect(
        summarize(values, window: ActivityWindow.day(2026, 9, 14)).seconds, 10);
    expect(day.startUtc, utc('2026-09-14T15:00:00Z'));
  });
  test('overlaps union before hour split and cannot exceed sixty minutes', () {
    final values = [
      interval('2026-09-14T15:00:00Z', '2026-09-14T16:00:20Z'),
      interval('2026-09-14T15:00:10Z', '2026-09-14T16:00:30Z')
    ];
    final result = summarize(values);
    expect(result.hours[0].seconds, 3600);
    expect(result.hours[1].seconds, 30);
    expect(result.seconds, 3630);
  });
  test('assignment camera move clips both cameras at the same instant', () {
    final result = summarize([
      interval('2026-09-15T02:59:50Z', '2026-09-15T03:00:20Z'),
      interval('2026-09-15T02:59:40Z', '2026-09-15T03:00:10Z', camera: 'b'),
    ], assignments: [
      ActivityAssignment(
          cameraId: 'a',
          startUtc: day.startUtc,
          endUtc: utc('2026-09-15T03:00:00Z')),
      ActivityAssignment(cameraId: 'b', startUtc: utc('2026-09-15T03:00:00Z')),
    ]);
    expect(result.seconds, 20);
    expect(result.hours[11].seconds, 10);
    expect(result.hours[12].seconds, 10);
  });
  test('before first assignment is not zero while legacy invents no start', () {
    final result = summarize([], assignments: [
      ActivityAssignment(cameraId: 'a', startUtc: utc('2026-09-15T03:00:00Z'))
    ]);
    expect(result.hours[0].state, ActivityObservation.beforeConnection);
    expect(result.hours[0].seconds, isNull);
    expect(legacy.startUtc, isNull);
    expect(summarize([]).state, ActivityObservation.missing);
  });
  test('completed zero included, missing excluded, selected day excluded', () {
    final results = [
      for (var d = 8; d <= 15; d++)
        summarize(
            d == 8
                ? [interval('2026-09-07T15:00:00Z', '2026-09-07T15:10:00Z')]
                : [],
            window: ActivityWindow.day(2026, 9, d),
            coverage: d == 8 || d == 9 || d == 15
                ? [
                    ActivityCoverage(
                        cameraId: 'a',
                        startUtc: ActivityWindow.day(2026, 9, d).startUtc,
                        endUtc: ActivityWindow.day(2026, 9, d).endUtc,
                        state: ActivityObservation.complete)
                  ]
                : [])
    ];
    final average = previousActivityAverage(day, results);
    expect(average.completedDays, 2);
    expect(average.seconds, 300);
    expect(results[1].seconds, 0);
    expect(results[2].seconds, isNull);
  });
  test('week starts Monday and includes today partial but not in average', () {
    final monday = ActivityWindow.day(2026, 9, 14);
    final days = [
      aggregateActivityDay(
          window: monday,
          assignments: [legacy],
          intervals: [interval('2026-09-13T15:00:00Z', '2026-09-13T15:10:00Z')],
          coverage: [
            ActivityCoverage(
                cameraId: 'a',
                startUtc: monday.startUtc,
                endUtc: monday.endUtc,
                state: ActivityObservation.complete)
          ],
          now: utc('2026-09-15T03:00:00Z')),
      aggregateActivityDay(
          window: day,
          assignments: [legacy],
          intervals: [interval('2026-09-14T15:00:00Z', '2026-09-14T15:05:00Z')],
          coverage: const [],
          now: utc('2026-09-15T03:00:00Z'))
    ];
    final week = ActivityWeekSummary(
        window: ActivityWindow.weekContaining(day), days: days);
    expect(week.window.startUtc, utc('2026-09-13T15:00:00Z'));
    expect(week.seconds, 900);
    expect(week.average.seconds, 600);
    expect(week.average.completedDays, 1);
  });
  test('estimated intervals never become an exact completed observation', () {
    final result = summarize([
      ActivityInterval(
          cameraId: 'a',
          startUtc: day.startUtc,
          endUtc: day.startUtc.add(const Duration(minutes: 3)),
          quality: ActivityQuality.legacyEstimate)
    ], coverage: [
      ActivityCoverage(
          cameraId: 'a',
          startUtc: day.startUtc,
          endUtc: day.endUtc,
          state: ActivityObservation.complete)
    ]);
    expect(result.seconds, 180);
    expect(result.isEstimated, isTrue);
    expect(previousActivityAverage(day.shiftDays(1), [result]).seconds, isNull);
  });
  test('assumedCoverage: 연결 기간의 지난 시간은 완료, 영상 없는 날은 0, 오늘은 진행 중', () {
    final now = utc('2026-09-15T03:00:00Z');
    final linked = ActivityAssignment(
        cameraId: 'a', startUtc: utc('2026-09-10T00:00:00Z'), endUtc: null);
    ActivityDaySummary dayOf(int d) {
      final window = ActivityWindow.day(2026, 9, d);
      return aggregateActivityDay(
          window: window,
          assignments: [linked],
          intervals: const [],
          coverage:
              assumedCoverage(assignments: [linked], window: window, now: now),
          now: now);
    }

    // 연결 전 날짜는 완료가 아니다.
    expect(dayOf(9).state, ActivityObservation.beforeConnection);
    // 연결 뒤 지난 날: 영상 없음 → 완료 + 0.
    final quiet = dayOf(12);
    expect(quiet.state, ActivityObservation.complete);
    expect(quiet.seconds, 0);
    expect(quiet.isComplete, isTrue);
    // 진행 중인 오늘(KST 9/15 = UTC 9/14 15:00~)은 완료가 아니다.
    final today = dayOf(15);
    expect(today.state, ActivityObservation.inProgress);
    expect(today.isComplete, isFalse);
    // 평균 분모에 조용한 날이 들어간다.
    final average = previousActivityAverage(ActivityWindow.day(2026, 9, 15),
        [for (var d = 8; d <= 14; d++) dayOf(d)]);
    expect(average.completedDays, 4); // 9/11~9/14 (9/10은 KST 경계상 부분)
    expect(average.seconds, 0);
  });
}
