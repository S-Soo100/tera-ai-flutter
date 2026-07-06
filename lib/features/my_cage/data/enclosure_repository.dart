import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/enclosure.dart';

/// `enclosures` 테이블 접근. 조회는 RLS로 본인 소유만 반환된다.
class EnclosureRepository {
  final SupabaseClient _supabase;

  EnclosureRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── Supabase 직결 ──────────────────────────────────────────────────────────

  /// 현재 유저의 사육장 전체 목록 (최신순).
  Future<List<Enclosure>> listAll() async {
    final rows = await _supabase
        .from('enclosures')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Enclosure.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 단일 사육장 조회. 없으면 null.
  Future<Enclosure?> getById(String id) async {
    final rows =
        await _supabase.from('enclosures').select().eq('id', id).limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Enclosure.fromJson(list.first as Map<String, dynamic>);
  }

  /// 사육장 생성. owner_id는 현재 로그인 유저로 세팅(RLS가 본인 것만 허용).
  /// 생성된 행을 Enclosure로 반환. 세션이 없으면 StateError.
  Future<Enclosure> create({
    required String name,
    String? species,
    String? note,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('사육장 생성 실패: 로그인 세션이 없습니다.');
    }
    final row = await _supabase.from('enclosures').insert({
      'owner_id': userId,
      'name': name,
      if (species != null) 'species': species,
      if (note != null) 'note': note,
    }).select().single();
    return Enclosure.fromJson(row);
  }
}
