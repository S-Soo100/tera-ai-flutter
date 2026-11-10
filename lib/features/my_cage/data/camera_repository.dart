import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/terra_rest_client.dart';
import '../domain/sys_health.dart';
import '../domain/terra_camera.dart';

/// 이 계정 목록에 보일 카메라 행인가 — 해제(`unlinked_at`)되지 않았고 다른
/// 계정으로 넘어가지(`superseded_at`) 않았다. `superseded_at`은 **cameras에만**
/// 있다(devices 행에 쓰지 말 것).
bool isVisibleCameraRow(Map<String, Object?> row) =>
    row['unlinked_at'] == null && row['superseded_at'] == null;

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
  ///
  /// 다른 계정이 같은 보드를 등록해 서버가 `superseded_at`을 찍은 옛 행도
  /// 뺀다(2026-11-10 서버 계약 — 해제는 아니고, 보드가 돌아오면 서버가 풀어
  /// cameras Realtime으로 다시 나타난다).
  Future<List<TerraCamera>> listAll() async {
    final rows = await _supabase
        .from('cameras')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where(isVisibleCameraRow)
        .map(TerraCamera.fromJson)
        .toList();
  }

  Future<TerraCamera?> getById(String id) async {
    final rows = await _supabase.from('cameras').select().eq('id', id).limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty || !isVisibleCameraRow(list.first)) return null;
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
  /// (잠시 뒤 다시). 판정은 [cameraRebootAccepted]. 해제·타인 카메라는
  /// 404([TerraRestException]). 카메라의 ack는 오지 않는다 — 완료는
  /// `clip_stats` 변화로 판정한다. `msg_id`는 서버 로그 추적용으로 남긴다.
  Future<bool> reboot(String cameraUuid) async {
    final body = await _rest.post('/cameras/$cameraUuid/reboot');
    final map = body is Map ? body : const {};
    debugPrint('[camera-reboot] cam=$cameraUuid published=${map['published']} '
        'msg_id=${map['msg_id']}');
    return cameraRebootAccepted(body);
  }
}
