import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/env_chart_series.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';

TelemetryBucket _b(String iso, {double? t, double? h}) =>
    TelemetryBucket.fromJson({
      'bucket': iso,
      'sample_count': 600,
      't_a_avg': t,
      't_a_min': t,
      't_a_max': t,
      'h_a_avg': h,
      'h_a_min': h,
      'h_a_max': h,
    });

void main() {
  group('EnvChartSeries.from', () {
    test('온도·습도가 같은 길이로 나온다 (두 선의 X축 일치)', () {
      final s = EnvChartSeries.from([
        _b('2026-08-05T19:00:00Z', t: 25, h: 60),
        _b('2026-08-05T19:30:00Z', t: 26, h: 62),
        _b('2026-08-05T20:00:00Z', t: 27, h: 64),
      ]);
      expect(s.temps.length, s.humids.length);
      expect(s.temps, [25, 26, 27]);
      expect(s.humids, [60, 62, 64]);
    });

    test('한쪽만 결측인 버킷은 통째로 제외해 길이 어긋남을 막는다', () {
      final s = EnvChartSeries.from([
        _b('2026-08-05T19:00:00Z', t: 25, h: 60),
        _b('2026-08-05T19:30:00Z', t: 26, h: 0), // 습도 센티넬
        _b('2026-08-05T20:00:00Z', t: 27, h: 64),
      ]);
      expect(s.temps, [25, 27]);
      expect(s.humids, [60, 64]);
    });

    test('0 센티넬 버킷은 버린다', () {
      final s = EnvChartSeries.from([
        _b('2026-08-05T19:00:00Z', t: 0, h: 0),
        _b('2026-08-05T19:30:00Z', t: 26, h: 62),
        _b('2026-08-05T20:00:00Z', t: 27, h: 64),
      ]);
      expect(s.temps, [26, 27]);
    });

    test('from/to는 차트 요청 구간이 아니라 실제 버킷 범위다', () {
      final s = EnvChartSeries.from([
        _b('2026-08-06T04:00:00Z', t: 27, h: 64),
        _b('2026-08-06T03:00:00Z', t: 26, h: 62),
      ]);
      // 정렬돼서 이른 시각이 from
      expect(s.from, DateTime.parse('2026-08-06T03:00:00Z'));
      expect(s.to, DateTime.parse('2026-08-06T04:00:00Z'));
    });

    test('입력이 뒤섞여 와도 시간순으로 정렬한다', () {
      final s = EnvChartSeries.from([
        _b('2026-08-05T20:00:00Z', t: 27, h: 64),
        _b('2026-08-05T19:00:00Z', t: 25, h: 60),
        _b('2026-08-05T19:30:00Z', t: 26, h: 62),
      ]);
      expect(s.temps, [25, 26, 27]);
    });

    test('표본 1개면 선을 그리지 않는다', () {
      final s = EnvChartSeries.from([_b('2026-08-05T19:00:00Z', t: 25, h: 60)]);
      expect(s.hasLine, isFalse);
      expect(s.from, isNull);
    });

    test('빈 입력도 죽지 않는다', () {
      final s = EnvChartSeries.from(const []);
      expect(s.hasLine, isFalse);
      expect(s.temps, isEmpty);
    });
  });
}
