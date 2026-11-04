import '../../features/my_cage/domain/telemetry_bucket.dart';

/// PRD §3.4 "당일(07:00~) 최고/최저 온도 및 습도".
///
/// `telemetry_30m`의 **0값은 실측이 아니라 센서 오프라인 센티넬**이다
/// (DHT22는 0을 못 낸다). 필터하지 않으면 최저가 항상 0으로 찍힌다.
class EnvExtremes {
  final double? tempMin;
  final double? tempMax;
  final double? humidMin;
  final double? humidMax;

  const EnvExtremes({
    required this.tempMin,
    required this.tempMax,
    required this.humidMin,
    required this.humidMax,
  });

  /// 온도·습도 중 하나라도 유효 표본이 있으면 true.
  bool get hasData => tempMin != null || humidMin != null;

  /// 실시간 현재값을 더한 최고/최저 — 오늘 화면에서 현재값이 최고보다 높게
  /// 보이지 않게 한다(2026-11-04). null·0·비정상 값은 무시한다.
  EnvExtremes including({double? temperature, double? humidity}) {
    bool valid(double? v) => v != null && v.isFinite && v > 0;
    double? lo(double? a, double? v) =>
        !valid(v) ? a : (a == null || v! < a ? v : a);
    double? hi(double? a, double? v) =>
        !valid(v) ? a : (a == null || v! > a ? v : a);
    return EnvExtremes(
      tempMin: lo(tempMin, temperature),
      tempMax: hi(tempMax, temperature),
      humidMin: lo(humidMin, humidity),
      humidMax: hi(humidMax, humidity),
    );
  }

  factory EnvExtremes.from(List<TelemetryBucket> buckets) {
    final temps = <double>[];
    final humids = <double>[];
    for (final b in buckets) {
      for (final v in [b.tMin, b.tMax]) {
        if (v != null && v > 0) temps.add(v);
      }
      for (final v in [b.hMin, b.hMax]) {
        if (v != null && v > 0) humids.add(v);
      }
    }
    return EnvExtremes(
      tempMin: temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b),
      tempMax: temps.isEmpty ? null : temps.reduce((a, b) => a > b ? a : b),
      humidMin: humids.isEmpty ? null : humids.reduce((a, b) => a < b ? a : b),
      humidMax: humids.isEmpty ? null : humids.reduce((a, b) => a > b ? a : b),
    );
  }
}
