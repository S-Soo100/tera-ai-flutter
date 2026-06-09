import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/device.dart';
import '../domain/device_command.dart';
import '../domain/telemetry_reading.dart';

/// terra-server commands/devices/telemetry Supabase 직결 repository.
/// 기존 [ModuleControlRepository](ESP32 직결 HTTP)는 PR5까지 병행 유지.
class SupabaseModuleControlRepository {
  final SupabaseClient _supabase;

  SupabaseModuleControlRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── 명령 발행 ──────────────────────────────────────────────────────────────

  /// `commands` 테이블 INSERT → select().single() → [DeviceCommand] 반환.
  /// 예외는 그대로 throw (Supabase PostgrestException).
  Future<DeviceCommand> sendCommand({
    required String deviceId,
    required CommandAction action,
    Map<String, dynamic>? payload,
    int? ttlSec,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'issued_by': _supabase.auth.currentUser!.id,
      'action': action.toWire(),
      if (payload != null) 'payload': payload,
      if (ttlSec != null) 'ttl_sec': ttlSec,
    };
    final row = await _supabase
        .from('commands')
        .insert(body)
        .select()
        .single();
    return DeviceCommand.fromJson(row);
  }

  // ── 편의 메서드 ────────────────────────────────────────────────────────────

  Future<DeviceCommand> toggleFan(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.fanToggle);

  Future<DeviceCommand> toggleRelay(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.relayToggle);

  Future<DeviceCommand> toggleHeater(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.heaterToggle);

  Future<DeviceCommand> clearHeater(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.heaterClear);

  Future<DeviceCommand> ledOn(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.ledOn);

  Future<DeviceCommand> ledUp(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.ledUp);

  Future<DeviceCommand> ledDown(String deviceId) =>
      sendCommand(deviceId: deviceId, action: CommandAction.ledDown);

  // ── 디바이스 목록 ──────────────────────────────────────────────────────────

  /// RLS가 본인 소유 디바이스만 반환.
  Future<List<Device>> listDevices() async {
    final rows = await _supabase
        .from('devices')
        .select()
        .order('last_seen_at', ascending: false);
    return (rows as List)
        .map((r) => Device.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── 텔레메트리 최신값 ──────────────────────────────────────────────────────

  /// 특정 디바이스의 가장 최신 telemetry 1건. 없으면 null.
  Future<TelemetryReading?> latestTelemetry(String deviceId) async {
    final rows = await _supabase
        .from('telemetry')
        .select()
        .eq('device_id', deviceId)
        .order('ts', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return TelemetryReading.fromJson(list.first as Map<String, dynamic>);
  }
}
