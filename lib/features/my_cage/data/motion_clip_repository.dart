import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// 구간 [from, to) 의 움직임 시간(초) = motion_clips duration_sec 합.
  Future<int> motionSeconds(
      String cameraId, DateTime from, DateTime to) async {
    final rows = await _supabase
        .from('motion_clips')
        .select('duration_sec')
        .eq('camera_id', cameraId)
        .gte('started_at', from.toUtc().toIso8601String())
        .lt('started_at', to.toUtc().toIso8601String())
        .limit(5000);
    var sec = 0.0;
    for (final r in rows as List) {
      sec += ((r as Map<String, dynamic>)['duration_sec'] as num?)
              ?.toDouble() ??
          0;
    }
    return sec.round();
  }
}
