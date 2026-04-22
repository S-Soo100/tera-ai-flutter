import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/clip.dart';
import '../domain/clip_page.dart';

class ClipRepository {
  final SupabaseClient _supabase;
  final String _backendUrl;
  final Future<String?> Function() _tokenProvider;

  ClipRepository({
    required SupabaseClient supabase,
    required String backendUrl,
    required Future<String?> Function() tokenProvider,
  })  : _supabase = supabase,
        _backendUrl = backendUrl,
        _tokenProvider = tokenProvider;

  // ── Supabase 직결 페이징 ───────────────────────────────────────────────────

  /// cursor-based 페이징. cursor는 이전 페이지 마지막 아이템의 startedAt.
  Future<ClipPage> listPage({
    String? cameraId,
    bool? hasMotion,
    DateTime? from,
    DateTime? to,
    int limit = 20,
    DateTime? cursor,
  }) async {
    // PostgrestFilterBuilder<PostgrestList> 타입을 명시해
    // 조건부 체인에서 타입 안정성을 확보한다.
    PostgrestFilterBuilder<PostgrestList> q =
        _supabase.from('camera_clips').select();

    if (cameraId != null) q = q.eq('camera_id', cameraId);
    if (hasMotion != null) q = q.eq('has_motion', hasMotion);
    if (from != null) q = q.gte('started_at', from.toIso8601String());
    if (to != null) q = q.lte('started_at', to.toIso8601String());
    if (cursor != null) q = q.lt('started_at', cursor.toIso8601String());

    final rows = await q.order('started_at', ascending: false).limit(limit);

    final items = (rows as List)
        .map((r) => Clip.fromJson(r as Map<String, dynamic>))
        .toList();

    return ClipPage(
      items: items,
      nextCursor: items.isNotEmpty ? items.last.startedAt : null,
      hasMore: items.length == limit,
    );
  }

  /// 1시간 범위(gte ≤ started_at < lt)의 클립을 시간순(ASC)으로 반환.
  /// 페이징 없음 — 1시간 최대 60개 가정.
  Future<List<Clip>> listInRange({
    required String cameraId,
    required DateTime startedAtGte,
    required DateTime startedAtLt,
    bool? hasMotion,
  }) async {
    PostgrestFilterBuilder<PostgrestList> q = _supabase
        .from('camera_clips')
        .select()
        .eq('camera_id', cameraId)
        .gte('started_at', startedAtGte.toUtc().toIso8601String())
        .lt('started_at', startedAtLt.toUtc().toIso8601String());

    if (hasMotion != null) q = q.eq('has_motion', hasMotion);

    final rows = await q.order('started_at', ascending: true);

    return (rows as List)
        .map((r) => Clip.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 해당 날짜(로컬 기준 00:00~24:00)의 시간대별 클립 개수.
  /// started_at만 select 후 Dart에서 Map(hour→count)로 grouping.
  Future<Map<int, int>> countByHourForDate({
    required String cameraId,
    required DateTime date,
    bool? hasMotion,
  }) async {
    // 로컬 기준 하루 범위를 UTC로 변환
    final localDay = DateTime(date.year, date.month, date.day);
    final localDayEnd = localDay.add(const Duration(days: 1));
    final gteUtc = localDay.toUtc().toIso8601String();
    final ltUtc = localDayEnd.toUtc().toIso8601String();

    PostgrestFilterBuilder<PostgrestList> q = _supabase
        .from('camera_clips')
        .select('started_at')
        .eq('camera_id', cameraId)
        .gte('started_at', gteUtc)
        .lt('started_at', ltUtc);

    if (hasMotion != null) q = q.eq('has_motion', hasMotion);

    final rows = await q;

    // 0~23 전체 키를 0으로 초기화
    final result = <int, int>{for (var h = 0; h < 24; h++) h: 0};

    for (final row in (rows as List)) {
      final rawAt = (row as Map<String, dynamic>)['started_at'] as String;
      final localHour = DateTime.parse(rawAt).toLocal().hour;
      result[localHour] = (result[localHour] ?? 0) + 1;
    }

    return result;
  }

  /// 가장 최근 클립의 startedAt (초기 진입 점프용).
  Future<DateTime?> getLatestStartedAt({required String cameraId}) async {
    final rows = await _supabase
        .from('camera_clips')
        .select('started_at')
        .eq('camera_id', cameraId)
        .order('started_at', ascending: false)
        .limit(1);

    final list = rows as List;
    if (list.isEmpty) return null;
    final raw = (list.first as Map<String, dynamic>)['started_at'] as String;
    return DateTime.parse(raw);
  }

  Future<Clip?> getById(String id) async {
    final rows = await _supabase
        .from('camera_clips')
        .select()
        .eq('id', id)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Clip.fromJson(list.first as Map<String, dynamic>);
  }

  // ── Backend URL 생성 (파일/썸네일) ─────────────────────────────────────────

  /// mp4 스트리밍 URL. video_player에 넘길 것.
  String fileUrl(String id) => '$_backendUrl/clips/$id/file';

  /// 썸네일 이미지 URL. thumbnailPath == null인 레거시 클립은 caller가 placeholder 표시.
  String thumbnailUrl(String id) => '$_backendUrl/clips/$id/thumbnail';

  /// Authorization 헤더. video_player httpHeaders, CachedNetworkImage httpHeaders에 사용.
  Future<Map<String, String>> authHeaders() async {
    final token = await _tokenProvider();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }
}
