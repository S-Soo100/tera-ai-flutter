import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';

void main() {
  // 2026-09-28 백엔드 표시 규칙: 값은 정상 행에서만 덮어쓰고 지우지 않는다.
  group('현재 온습도 — 마지막 정상값 유지', () {
    final base = DateTime.utc(2026, 9, 28, 7, 0, 0);
    TelemetryReading row(int sec,
            {String id = 'd',
            double? t = 28,
            double? h = 60,
            bool ok = true}) =>
        TelemetryReading.fromJson({
          'device_id': id,
          'ts': base.add(Duration(seconds: sec)).toIso8601String(),
          't_a': t,
          'h_a': h,
          'a_ok': ok
        });
    EnvLiveReading feed(List<TelemetryReading> rows) {
      var r = const EnvLiveReading(deviceId: 'd');
      for (final x in rows) {
        r = r.next(x);
      }
      return r;
    }

    test('센서 단발 실패(a_ok=false, t_a NULL)에도 값을 지우지 않는다', () {
      final r = feed([row(0), row(3, t: null, h: null, ok: false)]);
      expect(r.temperature, 28);
      expect(r.humidity, 60);
      expect(r.measuredAt!.isAtSameMomentAs(base), isTrue);
      expect(r.consecutiveFaults, 1);
      final v = envLiveView(r, now: base.add(const Duration(seconds: 4)));
      expect(v.temperature, 28);
      expect(v.freshness, EnvFreshness.fresh);
      expect(v.sensorError, isFalse, reason: '단발 실패는 표시하지 않는다');
    });

    test('실패가 10번 이어지면(약 30초) 센서 오류, 정상 행이 오면 풀린다', () {
      var r = feed([
        row(0),
        for (var i = 1; i <= 10; i++) row(i * 3, t: null, h: null, ok: false),
      ]);
      expect(
          envLiveView(r, now: base.add(const Duration(seconds: 31)))
              .sensorError,
          isTrue);
      expect(r.temperature, 28, reason: '값은 그대로');
      r = r.next(row(33, t: 29));
      expect(r.consecutiveFaults, 0);
      expect(r.temperature, 29);
    });

    test('정수로 온 값(27, 43)도 받는다', () {
      final r = feed([
        TelemetryReading.fromJson({
          'device_id': 'd',
          'ts': base.toIso8601String(),
          't_a': 27,
          'h_a': 43,
          'a_ok': true
        })
      ]);
      expect(r.temperature, 27.0);
      expect(r.humidity, 43.0);
    });

    test('폰 시계가 서버보다 늦어 경과가 음수여도 값을 버리지 않는다', () {
      final v = envLiveView(feed([row(0)]),
          now: base.subtract(const Duration(seconds: 1)));
      expect(v.temperature, 28);
      expect(v.age, Duration.zero);
      expect(v.freshness, EnvFreshness.fresh);
    });

    test('15초 안은 그대로, 넘으면 흐리게(값 유지), 서버가 오프라인이면 오프라인', () {
      final r = feed([row(0)]);
      expect(
          envLiveView(r, now: base.add(const Duration(seconds: 14))).freshness,
          EnvFreshness.fresh);
      final aging = envLiveView(r, now: base.add(const Duration(seconds: 40)));
      expect(aging.freshness, EnvFreshness.aging);
      expect(aging.temperature, 28);
      expect(aging.age, const Duration(seconds: 40));
      final off = envLiveView(r,
          now: base.add(const Duration(seconds: 5)), online: false);
      expect(off.freshness, EnvFreshness.offline);
      expect(off.temperature, 28);
    });

    test('다른 기기 행·늦게 온 옛 정상 행·0 센티넬은 값을 바꾸지 않는다', () {
      final r = feed([row(10), row(12, id: 'other', t: 99), row(3, t: 20)]);
      expect(r.temperature, 28);
      expect(r.measuredAt!.isAtSameMomentAs(base.add(const Duration(seconds: 10))), isTrue);
      final zero = feed([row(0), row(3, t: 0, h: 0)]);
      expect(zero.temperature, 28, reason: '0은 센서 오프라인 센티넬');
    });
  });
  TelemetryBucket bucket(double t, double h, int? tc, int? hc) =>
      TelemetryBucket(
          bucket: DateTime(2026),
          sampleCount: 100,
          tAvg: t,
          tMin: t,
          tMax: t,
          hAvg: h,
          hMin: h,
          hMax: h,
          tValidCount: tc,
          hValidCount: hc);
  test('일평균 provider는 지표별 유효 개수로 별도 가중한다', () async {
    final container = ProviderContainer(overrides: [
      envDayBucketsProvider.overrideWith(
          (ref) async => [bucket(20, 40, 1, 3), bucket(30, 60, 3, 1)])
    ]);
    addTearDown(container.dispose);
    final result = await container.read(envDailyAverageProvider.future);
    expect(
        result, (temperature: 27.5, humidity: 45.0, countUnavailable: false));
  });
  test('count 미지원은 raw sampleCount로 대체하거나 일부 평균으로 숨기지 않는다', () async {
    final container = ProviderContainer(overrides: [
      envDayBucketsProvider.overrideWith(
          (ref) async => [bucket(20, 40, null, 3), bucket(30, 60, 3, 1)])
    ]);
    addTearDown(container.dispose);
    final result = await container.read(envDailyAverageProvider.future);
    expect(result, (temperature: null, humidity: 45.0, countUnavailable: true));
  });
}
