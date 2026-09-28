import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/terra_rest_client.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/sys_health.dart';

/// 재시작 명령 행의 상태 — `commands.status`·`result` 원문. [DeviceCommand]의
/// 열거형은 `no_ack`·`lost`를 모른다(unknown으로 뭉갠다) — 원문으로 본다.
typedef RebootCommandState = ({String? status, String? result});

/// 사육장 기기 재시작·heartbeat(2026-09-28, petcam 요청서
/// `docs/references/2026-09-28-device-reboot-rssi-request.md`).
class DeviceHealthRepository {
  DeviceHealthRepository(this._supabase, this._rest);
  final SupabaseClient _supabase;
  final TerraRestClient _rest;

  /// `devices.sys_state`·`last_seen_at`·`is_online` — 서버 배포 전엔 `sys_state`가
  /// 늘 null이라 버튼·배너가 안 보인다(대응 불필요).
  Future<SysHealth> fetchHealth(String deviceUuid) async {
    final rows = await _supabase
        .from('devices')
        .select('sys_state,last_seen_at,is_online')
        .eq('id', deviceUuid)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? SysHealth.empty : SysHealth.fromDeviceRow(list.first);
  }

  /// `POST /devices/{uuid}/reboot`(본문 없음) — 서버가 소유권 검증·TTL 60초를
  /// 넣어 `commands` 행을 만든다(직결 INSERT 대신 REST, 요청서 §2-2). 반환은 그
  /// 명령 id — 결과(acked/no_ack)는 commands 행으로 본다. 404=해제·타인 기기.
  Future<String> reboot(String deviceUuid) async {
    final body = await _rest.post('/devices/$deviceUuid/reboot');
    final id = body is Map ? body['id'] : null;
    if (id is! String || id.isEmpty) {
      throw const TerraRestException(500, 'reboot response without id');
    }
    return id;
  }

  /// 명령 행 한 번 읽기 — Realtime 구독 전에 이미 바뀐 상태를 놓치지 않게.
  Future<RebootCommandState?> fetchCommand(String commandId) async {
    final rows = await _supabase
        .from('commands')
        .select('status,result')
        .eq('id', commandId)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return commandStateOf(list.first);
  }

  static RebootCommandState commandStateOf(Map<String, dynamic> row) => (
        status: row['status'] is String ? row['status'] as String : null,
        result: row['result'] is String ? row['result'] as String : null
      );
}

final deviceHealthRepositoryProvider = Provider<DeviceHealthRepository>((ref) =>
    DeviceHealthRepository(
        ref.watch(supabaseClientProvider), ref.watch(terraRestClientProvider)));
