import 'actuator_state.dart';

/// Supabase `telemetry` row 매핑.
/// relay/fan/heater_state: DB에서 bool 또는 "ON"/"OFF" 문자열 둘 다 허용.
class TelemetryReading {
  final String deviceId;
  final double? tA;
  final double? hA;
  final bool aOk;
  final double? tB;
  final double? hB;
  final bool bOk;
  final ActuatorState relay;
  final ActuatorState fan;
  final ActuatorState heaterState;
  final bool heaterLocked;
  final DateTime? ts;

  const TelemetryReading({
    required this.deviceId,
    required this.tA,
    required this.hA,
    required this.aOk,
    required this.tB,
    required this.hB,
    required this.bOk,
    required this.relay,
    required this.fan,
    required this.heaterState,
    required this.heaterLocked,
    required this.ts,
  });

  factory TelemetryReading.fromJson(Map<String, dynamic> j) {
    return TelemetryReading(
      deviceId: j['device_id'] as String? ?? '',
      tA: _parseDouble(j['t_a']),
      hA: _parseDouble(j['h_a']),
      aOk: j['a_ok'] as bool? ?? false,
      tB: _parseDouble(j['t_b']),
      hB: _parseDouble(j['h_b']),
      bOk: j['b_ok'] as bool? ?? false,
      relay: _parseActuator(j['relay']),
      fan: _parseActuator(j['fan']),
      heaterState: _parseActuator(j['heater_state']),
      heaterLocked: j['heater_locked'] as bool? ?? false,
      ts: j['ts'] != null ? DateTime.tryParse(j['ts'].toString()) : null,
    );
  }

  /// 편의 getter: HeaterState(기존 모델 재사용).
  HeaterState get heater =>
      HeaterState(state: heaterState, locked: heaterLocked);

  /// DB 컬럼은 bool 또는 "ON"/"OFF" 문자열 둘 다 올 수 있다.
  static ActuatorState _parseActuator(Object? v) {
    if (v is bool) {
      return v ? ActuatorState.on : ActuatorState.off;
    }
    if (v is String) {
      return actuatorFromString(v);
    }
    return ActuatorState.unavailable;
  }

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
