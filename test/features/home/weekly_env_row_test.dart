import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/weekly_env_row.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/stats/domain/daily_rollup.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';

final _now = DateTime(2026, 8, 12, 15, 43);
final _window = ChartWindow.homeWeekly(_now);

TelemetryBucket _b(DateTime at, {double? t, double? h}) => TelemetryBucket(
      bucket: at,
      sampleCount: 1,
      tAvg: t,
      tMin: t == null ? null : t - 1,
      tMax: t == null ? null : t + 1,
      hAvg: h,
      hMin: h,
      hMax: h,
    );

/// 8/6~8/12(오늘) 각 날 정오에 한 버킷씩. 오늘은 25도, 과거는 20~26.
List<TelemetryBucket> _week() => [
      _b(DateTime(2026, 8, 6, 12), t: 20, h: 60),
      _b(DateTime(2026, 8, 7, 12), t: 22, h: 61),
      _b(DateTime(2026, 8, 8, 12), t: 26, h: 62),
      _b(DateTime(2026, 8, 9, 12), t: 23, h: 63),
      _b(DateTime(2026, 8, 10, 12), t: 24, h: 64),
      _b(DateTime(2026, 8, 11, 12), t: 21, h: 65),
      _b(DateTime(2026, 8, 12, 12), t: 25, h: 66),
    ];

WeeklyEnvRows _rows({List<ActuatorMarker> markers = const []}) =>
    WeeklyEnvRows.from(
      days: rollupByDay(_week(), window: _window),
      window: _window,
      markers: markers,
    );

void main() {
  group('오늘 행 합성', () {
    test('7행이고 오늘이 맨 위, 아래로 과거 6일', () {
      final r = _rows();
      expect(r.rows, hasLength(7));
      expect(r.rows.first.isToday, isTrue);
      expect(r.rows.first.day, DateTime(2026, 8, 12, 7));
      expect(r.rows.last.day, DateTime(2026, 8, 6, 7));
      expect(r.rows.where((x) => x.isToday), hasLength(1));
    });

    test('오늘 행의 min/max는 07시부터 지금까지 값이다', () {
      final r = _rows();
      final today = r.rows.first;
      expect(today.tMin, 24);
      expect(today.tMax, 26);
      expect(today.hAvg, 66);
    });

    test('07시 이전이면 오늘 = 어제 07시 시작 날 — 새벽 값이 어제 행에 붙는다', () {
      final now = DateTime(2026, 8, 12, 3);
      final w = ChartWindow.homeWeekly(now);
      final r = WeeklyEnvRows.from(
        days: rollupByDay([_b(DateTime(2026, 8, 12, 2), t: 22)], window: w),
        window: w,
        markers: const [],
      );
      expect(r.rows.first.isToday, isTrue);
      expect(r.rows.first.day, DateTime(2026, 8, 11, 7));
      expect(r.rows.first.tMax, 23);
    });

    test('버킷이 없으면 빈 결과 — 자리를 지어내지 않는다', () {
      final r = WeeklyEnvRows.from(
          days: const [], window: _window, markers: const []);
      expect(r.rows, isEmpty);
      expect(r.hasData, isFalse);
    });

    test('값이 없는 날도 행은 남는다(바만 비운다) — 빼면 요일이 밀린다', () {
      final w = ChartWindow.homeWeekly(_now);
      final r = WeeklyEnvRows.from(
        days: rollupByDay([_b(DateTime(2026, 8, 12, 12), t: 25)], window: w),
        window: w,
        markers: const [],
      );
      expect(r.rows, hasLength(7));
      expect(r.rows[1].hasRange, isFalse);
      expect(r.hasData, isTrue);
    });
  });

  group('트랙 min/max — 이번 주 전체', () {
    test('트랙은 7일 전체의 최저~최고다', () {
      final r = _rows();
      expect(r.trackMin, 19); // 8/6 20-1
      expect(r.trackMax, 27); // 8/8 26+1
    });

    test('점 위치는 0~1로 클램프된다 — 실시간 값이 30분 집계를 넘어도 튀지 않는다', () {
      final r = _rows();
      expect(r.positionOf(19), 0);
      expect(r.positionOf(27), 1);
      expect(r.positionOf(23), closeTo(0.5, 1e-9));
      expect(r.positionOf(40), 1);
      expect(r.positionOf(-5), 0);
      expect(r.positionOf(null), isNull);
    });

    test('트랙이 없으면 위치도 없다', () {
      expect(WeeklyEnvRows.empty.positionOf(25), isNull);
    });
  });

  group('분무 횟수', () {
    test('acked 분무만 그날(07시 경계)로 센다', () {
      final r = _rows(markers: [
        ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 12, 9)),
        ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 12, 14)),
        // 8/12 06:00은 아직 8/11의 밤이다.
        ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 12, 6)),
        ActuatorMarker(kind: MarkerKind.fan, at: DateTime(2026, 8, 12, 10)),
      ]);
      expect(r.rows.first.mistCount, 2);
      expect(r.rows[1].mistCount, 1);
      expect(r.rows[2].mistCount, 0);
    });
  });
}
