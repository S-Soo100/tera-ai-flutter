import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cage_activity.dart';
import '../domain/motion_clip.dart';
import 'camera_exceptions.dart';

/// terra-server `motion_clips` 접근. 목록은 Supabase 직결(RLS 본인 것),
/// 재생 URL은 terra-api(R2 presigned).
class MotionClipRepository {
  final SupabaseClient _supabase;
  final String _terraApiUrl;
  final Future<String?> Function() _tokenProvider;

  MotionClipRepository({
    required SupabaseClient supabase,
    required String terraApiUrl,
    required Future<String?> Function() tokenProvider,
  })  : _supabase = supabase,
        _terraApiUrl = terraApiUrl,
        _tokenProvider = tokenProvider;

  /// 카메라의 모션 클립 목록 (최신순). [day]가 주어지면 그 날(로컬 00:00~24:00)로
  /// started_at 범위 필터. RLS로 본인 카메라 것만.
  Future<List<MotionClip>> listByCamera(String cameraId,
      {int limit = 50, DateTime? day}) async {
    var q = _supabase.from('motion_clips').select().eq('camera_id', cameraId);
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      q = q
          .gte('started_at', start.toUtc().toIso8601String())
          .lt('started_at', end.toUtc().toIso8601String());
    }
    final rows =
        await q.order('started_at', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => MotionClip.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 재생용 presigned URL (terra-api GET /clips/{id}/url). TTL 1h.
  Future<String> getPlaybackUrl(String clipId) async {
    final token = await _tokenProvider();
    final resp = await http.get(
      Uri.parse('$_terraApiUrl/clips/$clipId/url'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['url'] as String;
    }
    throw BackendException(resp.statusCode, resp.body);
  }

  /// 썸네일 presigned URL (terra-api GET /clips/{id}/thumbnail/url).
  /// 응답 {url, expires_in}. 썸네일 없으면(404) null → 카드 아이콘 폴백.
  Future<String?> getThumbnailUrl(String clipId) async {
    final token = await _tokenProvider();
    final resp = await http.get(
      Uri.parse('$_terraApiUrl/clips/$clipId/thumbnail/url'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['url'] as String?;
    }
    if (resp.statusCode == 404) return null;
    throw BackendException(resp.statusCode, resp.body);
  }

  /// 단일 모션 클립 조회(즐겨찾기 메타용). 없으면 null. RLS 본인 것만.
  Future<MotionClip?> getById(String clipId) async {
    final rows = await _supabase
        .from('motion_clips')
        .select()
        .eq('id', clipId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return MotionClip.fromJson(list.first as Map<String, dynamic>);
  }

  /// 구간 [from, to) 의 움직임 시간(초) = motion_clips duration_sec 합.
  Future<int> motionSeconds(
      String cameraId, DateTime from, DateTime to) async {
    final rows = await _supabase
        .from('motion_clips')
        .select('duration_sec')
        .eq('camera_id', cameraId)
        .gte('started_at', from.toUtc().toIso8601String())
        .lt('started_at', to.toUtc().toIso8601String())
        // order 명시: 5000 상한 초과 시에도 motionSecondsByHour와 동일 부분집합을
        // 집어 총합/그래프 수치 불일치를 방지(현재는 여유 크나 값싼 방어).
        .order('started_at', ascending: true)
        .limit(5000);
    var sec = 0.0;
    for (final r in rows as List) {
      sec += ((r as Map<String, dynamic>)['duration_sec'] as num?)
              ?.toDouble() ??
          0;
    }
    return sec.round();
  }

  /// 구간 [from,to)를 1시간 버킷 24개로 나눈 시간대별 움직임 시간(초).
  /// index 0 = [from]이 속한 시각 ~ +1h. 홈·크레캠 활동 그래프 공용.
  Future<List<int>> motionSecondsByHour(
      String cameraId, DateTime from, DateTime to) async {
    final rows = await _supabase
        .from('motion_clips')
        .select('started_at, duration_sec')
        .eq('camera_id', cameraId)
        .gte('started_at', from.toUtc().toIso8601String())
        .lt('started_at', to.toUtc().toIso8601String())
        .order('started_at', ascending: true)
        .limit(5000);
    final clips = <({DateTime startedAt, double durationSec})>[];
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['started_at']?.toString() ?? '');
      if (ts == null) continue;
      clips.add((
        startedAt: ts,
        durationSec: (m['duration_sec'] as num?)?.toDouble() ?? 0.0,
      ));
    }
    return bucketMotionSecondsByHour(clips, from);
  }

  /// 이 카메라의 가장 최근 모션 클립 시각. 모션 이력이 없으면 null.
  /// 홈 대시보드 '대표(활성) 카메라' 선정용 — 최근 녹화가 있는 카메라를 고른다.
  Future<DateTime?> latestMotionAt(String cameraId) async {
    final rows = await _supabase
        .from('motion_clips')
        .select('started_at')
        .eq('camera_id', cameraId)
        .order('started_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final ts = (list.first as Map<String, dynamic>)['started_at'];
    return DateTime.tryParse(ts?.toString() ?? '');
  }
}
