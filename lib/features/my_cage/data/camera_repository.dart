import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/terra_rest_client.dart';
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

  Future<List<TerraCamera>> listAll() async {
    final rows = await _supabase
        .from('cameras')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => TerraCamera.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TerraCamera?> getById(String id) async {
    final rows =
        await _supabase.from('cameras').select().eq('id', id).limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return TerraCamera.fromJson(list.first as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _supabase.from('cameras').delete().eq('id', id);
  }

  /// 카메라를 사육장에 배정. enclosureId=null 이면 배정 해제.
  /// RLS(owner_id=auth.uid)로 본인 카메라만 UPDATE 가능.
  Future<void> assignEnclosure(String cameraId, String? enclosureId) async {
    await _supabase
        .from('cameras')
        .update({'enclosure_id': enclosureId})
        .eq('id', cameraId);
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
}
