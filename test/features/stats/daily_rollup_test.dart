import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/stats/domain/daily_rollup.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';

final _window = ChartWindow.weekly(DateTime(2026, 8, 12, 15));

TelemetryBucket _b(DateTime at, {double? t, double? h}) => TelemetryBucket(
      bucket: at,
      sampleCount: 1,
      tAvg: t,
      tMin: t == null ? null : t - 1,
      tMax: t == null ? null : t + 1,
      hAvg: h,
      hMin: h == null ? null : h - 2,
      hMax: h == null ? null : h + 2,
    );

void main() {
  group('하루 단위로 접기', () {
    test('07:00 경계로 나눈다 — 자정으로 끊으면 밤이 두 날로 쪼개진다', () {
      // 8/7 06:00은 아직 8/6의 밤이다.
      final out = rollupByDay([
        _b(DateTime(2026, 8, 7, 6), t: 20),
        _b(DateTime(2026, 8, 7, 8), t: 30),
      ], window: _window);

      final d6 = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 6, 7));
      final d7 = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 7, 7));
      expect(d6.tAvg, 20);
      expect(d7.tAvg, 30);
    });

    test('평균은 그 날 값들의 평균이다', () {
      final out = rollupByDay([
        _b(DateTime(2026, 8, 8, 8), t: 20, h: 40),
        _b(DateTime(2026, 8, 8, 20), t: 30, h: 60),
      ], window: _window);
      final d = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 8, 7));
      expect(d.tAvg, 25);
      expect(d.hAvg, 50);
    });

    test('최고·최저는 그 날 전체의 극값이다 — 평균의 극값이 아니다', () {
      final out = rollupByDay([
        _b(DateTime(2026, 8, 8, 8), t: 20), // min 19 / max 21
        _b(DateTime(2026, 8, 8, 20), t: 30), // min 29 / max 31
      ], window: _window);
      final d = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 8, 7));
      expect(d.tMin, 19);
      expect(d.tMax, 31);
    });

    test('0은 버린다 — 센서 오프라인 센티넬이지 실측이 아니다', () {
      // 0을 평균에 넣으면 그 날 온도가 반토막 난다.
      final out = rollupByDay([
        _b(DateTime(2026, 8, 8, 8), t: 30, h: 60),
        _b(DateTime(2026, 8, 8, 9), t: 0, h: 0),
      ], window: _window);
      final d = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 8, 7));
      expect(d.tAvg, 30);
      expect(d.hAvg, 60);
    });

    test('값이 하나도 없는 날은 빈 칸으로 남는다 — 0으로 내리꽂지 않는다', () {
      final out = rollupByDay([
        _b(DateTime(2026, 8, 8, 8), t: 30),
      ], window: _window);
      final empty = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 9, 7));
      expect(empty.tAvg, isNull);
      expect(empty.sampleCount, 0);
    });

    test('창의 7일이 빠짐없이 나온다 — 빈 날도 자리를 지킨다', () {
      // 주간 창은 완결된 7일: 8/12 15시 기준 8/5 07시 ~ 8/12 07시.
      final out = rollupByDay(const [], window: _window);
      expect(out, hasLength(7));
      expect(out.first.bucket, DateTime(2026, 8, 5, 7));
      expect(out.last.bucket, DateTime(2026, 8, 11, 7));
    });

    test('창 밖 데이터는 무시한다', () {
      final out = rollupByDay([
        _b(DateTime(2026, 8, 1, 8), t: 99),
      ], window: _window);
      expect(out.every((b) => b.tAvg == null), isTrue);
    });

    test('온도만 있고 습도가 없어도 각각 따로 센다', () {
      final out = rollupByDay([
        _b(DateTime(2026, 8, 8, 8), t: 30),
        _b(DateTime(2026, 8, 8, 9), h: 60),
      ], window: _window);
      final d = out.firstWhere((b) => b.bucket == DateTime(2026, 8, 8, 7));
      expect(d.tAvg, 30);
      expect(d.hAvg, 60);
    });
  });
}
