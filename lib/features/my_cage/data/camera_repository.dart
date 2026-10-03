import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/terra_rest_client.dart';
import '../domain/sys_health.dart';
import '../domain/terra_camera.dart';

class CameraRepository {
  final SupabaseClient _supabase;
  final TerraRestClient _rest;

  CameraRepository({
    required SupabaseClient supabase,
    required TerraRestClient rest,
  })  : _supabase = supabase,
        _rest = rest;

  // ── Supabase 직결 ──────────────────────────────────────────────────────────

  /// 소프트 해제된 카메라(`unlinked_at` 있음, 2026-09-16 가정 계약)는 뺀다.
  /// 컬럼 미배포면 null이라 전부 남는다 — 서버 필터 대신 앱에서 거른다(직결
  /// 조회에 없는 컬럼을 필터로 걸면 배포 전 400이 난다).
  Future<List<TerraCamera>> listAll() async {
    final rows = await _supabase
        .from('cameras')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['unlinked_at'] == null)
        .map(TerraCamera.fromJson)
        .toList();
  }

  Future<TerraCamera?> getById(String id) async {
    final rows = await _supabase.from('cameras').select().eq('id', id).limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty || list.first['unlinked_at'] != null) return null;
    return TerraCamera.fromJson(list.first);
  }

  /// 재시작 판정·Wi-Fi 약함용 heartbeat 값(`clip_stats`). **직결 조회만** —
  /// REST `GET /cameras`는 아직 `clip_stats`를 null로 준다(요청서 §1).
  Future<SysHealth> fetchHealth(String cameraUuid) async {
    final rows = await _supabase
        .from('cameras')
        .select('clip_stats,clip_stats_at')
        .eq('id', cameraUuid)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? SysHealth.empty : SysHealth.fromCameraRow(list.first);
  }

  // 카메라 hard delete는 앱에서 호출하지 않는다(2026-09-15 회신 §2.1 —
  // motion_clips cascade 삭제). 등록 해제는 RedesignGroupRepository.unlink.

  /// 카메라를 사육장에 배정. enclosureId=null 이면 배정 해제.
  /// RLS(owner_id=auth.uid)로 본인 카메라만 UPDATE 가능.
  Future<void> assignEnclosure(String cameraId, String? enclosureId) async {
    await _supabase
        .from('cameras')
        .update({'enclosure_id': enclosureId}).eq('id', cameraId);
  }

  // ── terra-server REST ──────────────────────────────────────────────────────

  /// 180° 회전 설정 (회신 2026-09-08 §5 — **REST 전용**). 서버가 DB 갱신 후
  /// MQTT `set_rotation`을 발행하고 재연결 시 동기화까지 책임진다 — Supabase
  /// 직결 UPDATE로는 명령이 안 나가 카메라가 다음 재연결까지 안 뒤집힌다.
  /// 응답은 DB 반영 즉시(카메라 적용 대기 없음) — 갱신 반영은 cameras
  /// Realtime이 되쏘는 UPDATE로 흘러온다.
  Future<void> setRotate180(String cameraUuid, bool on) async {
    await _rest.patch('/cameras/$cameraUuid', {'rotate_180': on});
  }

  /// 카메라 재시작(요청서 2026-09-28 §2-2) — 본문 없는 POST, 서버가 MQTT로
  /// 재시작 명령을 발행한다. 반환은 발행 여부 — false면 브로커에 못 보냈다
  /// (잠시 뒤 다시). 판정은 [cameraRebootAccepted] — 서버 버그로 지금은 200이면
  /// 성공으로 본다. 해제·타인 카메라는 404([TerraRestException]).
  /// 카메라의 ack는 오지 않는다 — 완료는 `clip_stats` 변화로 판정한다.
  Future<bool> reboot(String cameraUuid) async {
    final body = await _rest.post('/cameras/$cameraUuid/reboot');
    return cameraRebootAccepted(body);
  }
}
