import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/domain/env_thresholds.dart';
import '../../../shared/domain/num_format.dart';
import '../domain/device.dart';
import '../domain/device_command.dart';
import '../domain/telemetry_bucket.dart';
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
    final row = await _supabase.from('commands').insert(body).select().single();
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

  // ── 디바이스 목록 ──────────────────────────────────────────────────────────

  /// RLS가 본인 소유 디바이스만 반환. 소프트 해제된 기기(`unlinked_at`,
  /// 2026-09-16 가정 계약)는 앱에서 거른다 — 컬럼 미배포면 null이라 전부 남는다.
  Future<List<Device>> listDevices() async {
    final rows = await _supabase
        .from('devices')
        .select()
        .order('last_seen_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['unlinked_at'] == null)
        .map(Device.fromJson)
        .toList();
  }

  /// 기기 1대의 연결 상태(+LCD 문구). 해제(`unlinked_at`)됐거나 안 보이면 null.
  /// 컬럼을 고르지 않는다 — LCD 컬럼이 없는 서버에서도 깨지지 않게.
  Future<DeviceLinkStatus?> fetchLinkStatus(String deviceId) async {
    final rows =
        await _supabase.from('devices').select().eq('id', deviceId).limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty || list.first['unlinked_at'] != null) return null;
    return DeviceLinkStatus.fromJson(list.first);
  }

  /// 기기에 걸린 **사용자 보정값**. 구 펌웨어·없는 기기는 null. 목록 캐시가
  /// 아니라 매번 읽는다 — 보정을 바꾼 직후 다시 들어와도 옛 값이 보이지 않게
  /// (v4 1-2).
  ///
  /// 읽는 컬럼과 해석은 계약에 따라 [tempOffsetColumn]·[userOffsetFromRow]가
  /// 정한다(옛 계약 = 합산값 `temp_offset_c`에서 공장 보정을 걷어냄, 새 계약 =
  /// `temp_offset_user_c` 그대로).
  Future<TempOffset?> fetchUserTempOffset(String deviceId,
      {required bool userContract}) async {
    final rows = await _supabase
        .from('devices')
        .select(tempOffsetColumn(userContract: userContract))
        .eq('id', deviceId)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return userOffsetFromRow(list.first, userContract: userContract).offset;
  }

  /// 디바이스를 사육장에 배정. enclosureId=null 이면 배정 해제.
  /// RLS(owner_id=auth.uid)로 본인 디바이스만 UPDATE 가능.
  Future<void> assignEnclosure(String deviceId, String? enclosureId) async {
    await _supabase
        .from('devices')
        .update({'enclosure_id': enclosureId}).eq('id', deviceId);
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

  /// 마지막 **정상** 텔레메트리(`a_ok=true`) — 현재 온습도의 첫 값. 최신 1행은
  /// 센서 단발 실패 행일 수 있다(백엔드 표시 규칙 2026-09-28 §3.1).
  Future<TelemetryReading?> latestGoodTelemetry(String deviceId) async {
    final rows = await _supabase
        .from('telemetry')
        .select()
        .eq('device_id', deviceId)
        .eq('a_ok', true)
        .order('ts', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return TelemetryReading.fromJson(list.first as Map<String, dynamic>);
  }

  // ── 텔레메트리 히스토리 (telemetry_30m, 30분 집계 장기 추이) ──────────────────

  /// [deviceId]의 30분 집계 버킷을 [from](inclusive)부터 [to](exclusive, 옵션)까지
  /// bucket 오름차순으로 반환. RLS가 본인 디바이스만 필터하므로 owner 조건 불필요.
  /// 잘못된 device_id면 빈 리스트(에러 아님).
  Future<List<TelemetryBucket>> telemetryHistory(
    String deviceId,
    DateTime from, {
    DateTime? to,
  }) async {
    var q = _supabase
        .from('telemetry_30m')
        .select() // Optional per-metric valid counts can arrive without breaking old servers.
        .eq('device_id', deviceId)
        .gte('bucket', from.toUtc().toIso8601String());
    if (to != null) {
      q = q.lt('bucket', to.toUtc().toIso8601String());
    }
    final rows = await q.order('bucket', ascending: true);
    return (rows as List)
        .map((r) => TelemetryBucket.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// [telemetryHistory] + **아직 마감 전인 30분 칸**을 원본 `telemetry`로 채운 것.
  ///
  /// `telemetry_30m`은 칸이 끝나야 생겨서, 오늘 화면의 최고·최저·그래프가
  /// 최대 30분 넘게 늦었다(2026-11-04 — 오늘 최고 25.9인데 현재 26.9·알림
  /// 27.7). 오늘처럼 끝이 지금인 창에만 쓴다. 원본은 최근 1000행(약 1시간,
  /// PostgREST 상한)만 읽어, 집계가 더 밀려도 최신 쪽이 남는다.
  Future<List<TelemetryBucket>> telemetryHistoryWithTail(
    String deviceId,
    DateTime from, {
    DateTime? to,
  }) async {
    final closed = await telemetryHistory(deviceId, from, to: to);
    final tailFrom = TelemetryBucket.tailFrom(closed, from);
    if (to != null && !tailFrom.isBefore(to)) return closed;
    var q = _supabase
        .from('telemetry')
        .select('ts, t_a, h_a, a_ok')
        .eq('device_id', deviceId)
        .gte('ts', tailFrom.toUtc().toIso8601String());
    if (to != null) q = q.lt('ts', to.toUtc().toIso8601String());
    final rows = await q.order('ts', ascending: false).limit(1000);
    final samples = <RawEnvSample>[];
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final ts = DateTime.tryParse(r['ts']?.toString() ?? '');
      if (ts == null) continue;
      samples.add((
        ts: ts,
        t: parseDouble(r['t_a']),
        h: parseDouble(r['h_a']),
        ok: r['a_ok'] == true,
      ));
    }
    return TelemetryBucket.withOpenTail(
        closed, TelemetryBucket.aggregate(samples));
  }
}
