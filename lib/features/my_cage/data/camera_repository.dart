import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/terra_camera.dart';

class CameraRepository {
  final SupabaseClient _supabase;

  CameraRepository({required SupabaseClient supabase}) : _supabase = supabase;

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
}
