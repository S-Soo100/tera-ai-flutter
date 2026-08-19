import '../../../shared/domain/num_format.dart';
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

  /// LED 상태 (`telemetry.led`, 2026-08-18 백엔드 회신 §4). 구 펌웨어는 컬럼을
  /// 안 보내 [ActuatorState.unavailable]로 온다 — 그때는 "모른다"이지 "꺼짐"이
  /// 아니다.
  final ActuatorState led;

  /// LED 밝기 0~100 (`telemetry.led_brightness`). MOSFET 보드만 값이 있고
  /// 릴레이 보드·구 펌웨어는 null.
  final int? ledBrightness;
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
    this.led = ActuatorState.unavailable,
    this.ledBrightness,
  });

  factory TelemetryReading.fromJson(Map<String, dynamic> j) {
    return TelemetryReading(
      deviceId: j['device_id'] as String? ?? '',
      tA: parseDouble(j['t_a']),
      hA: parseDouble(j['h_a']),
      aOk: j['a_ok'] as bool? ?? false,
      tB: parseDouble(j['t_b']),
      hB: parseDouble(j['h_b']),
      bOk: j['b_ok'] as bool? ?? false,
      relay: _parseActuator(j['relay']),
      fan: _parseActuator(j['fan']),
      heaterState: _parseActuator(j['heater_state']),
      heaterLocked: j['heater_locked'] as bool? ?? false,
      led: _parseActuator(j['led']),
      ledBrightness: parseDouble(j['led_brightness'])?.round(),
      ts: parseLocalDateTime(j['ts']),
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
}
