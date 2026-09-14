import '../../my_cage/domain/telemetry_reading.dart';

typedef EnvRealtimeValues = ({double? temperature, double? humidity});
EnvRealtimeValues realtimeEnvironment(
  TelemetryReading? reading, {
  required String deviceId,
  required DateTime now,
  required Duration freshness,
  required bool stale,
}) {
  const empty = (temperature: null, humidity: null);
  if (reading == null ||
      reading.deviceId != deviceId ||
      !reading.aOk ||
      stale ||
      reading.ts == null) {
    return empty;
  }
  final age = now.difference(reading.ts!);
  if (age.isNegative || age > freshness) return empty;
  double? valid(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;
  return (temperature: valid(reading.tA), humidity: valid(reading.hA));
}
