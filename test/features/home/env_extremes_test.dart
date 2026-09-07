import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';

TelemetryBucket _b({
  required double tMin,
  required double tMax,
  required double hMin,
  required double hMax,
}) =>
    TelemetryBucket.fromJson({
      'bucket': '2026-08-05T09:00:00Z',
      'sample_count': 10,
      't_a_avg': (tMin + tMax) / 2,
      't_a_min': tMin,
      't_a_max': tMax,
      'h_a_avg': (hMin + hMax) / 2,
      'h_a_min': hMin,
      'h_a_max': hMax,
    });

void main() {
  group('EnvExtremes.from', () {
    test('여러 버킷에서 전체 최고/최저를 뽑는다', () {
      final e = EnvExtremes.from([
        _b(tMin: 23.5, tMax: 25.0, hMin: 60, hMax: 75),
        _b(tMin: 24.0, tMax: 26.0, hMin: 62, hMax: 82),
      ]);
      expect(e.tempMin, 23.5);
      expect(e.tempMax, 26.0);
      expect(e.humidMin, 60);
      expect(e.humidMax, 82);
    });

    test('0값은 센서 오프라인 센티넬 — 최저에 섞이면 안 된다', () {
      final e = EnvExtremes.from([
        _b(tMin: 0, tMax: 0, hMin: 0, hMax: 0),
        _b(tMin: 23.5, tMax: 26.0, hMin: 60, hMax: 82),
      ]);
      expect(e.tempMin, 23.5);
      expect(e.humidMin, 60);
    });

    test('유효 표본이 없으면 hasData=false', () {
      final e = EnvExtremes.from([_b(tMin: 0, tMax: 0, hMin: 0, hMax: 0)]);
      expect(e.hasData, isFalse);
      expect(e.tempMin, isNull);
    });

    test('빈 목록 → hasData=false', () {
      expect(EnvExtremes.from(const []).hasData, isFalse);
    });

    test('온도만 유효하고 습도가 전부 0이어도 온도는 살린다', () {
      final e = EnvExtremes.from([_b(tMin: 22, tMax: 25, hMin: 0, hMax: 0)]);
      expect(e.tempMin, 22);
      expect(e.humidMin, isNull);
      expect(e.hasData, isTrue);
    });
  });
}
