import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/behavior_inference.dart';
import '../domain/behavior_label.dart';
import '../domain/clip.dart';
import '../domain/clip_media_url.dart';
import '../domain/clip_page.dart';
import '../domain/highlights_page.dart';
import '../domain/labeler_status.dart';
import 'camera_exceptions.dart';

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

  // ── Backend API (JWT 필요) ─────────────────────────────────────────────────

  /// 서명된 파일 URL. TTL은 ClipMediaUrl.ttlSec 참조.
  Future<ClipMediaUrl> getFileUrl(String id, {int retries = 1}) async {
    try {
      final resp = await _authedRequest(() async => http.get(
            Uri.parse('$_backendUrl/clips/$id/file/url'),
            headers: await _authHeadersHttp(),
          ));
      if (resp.statusCode == 200) {
        return ClipMediaUrl.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      // 5xx만 retry, 4xx는 영구 에러
      if (retries > 0 && resp.statusCode >= 500) {
        await Future.delayed(const Duration(milliseconds: 500));
        return getFileUrl(id, retries: retries - 1);
      }
      throw BackendException(resp.statusCode, _extractDetail(resp.body));
    } on http.ClientException {
      if (retries > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        return getFileUrl(id, retries: retries - 1);
      }
      rethrow;
    }
  }

  /// 서명된 썸네일 URL. TTL은 ClipMediaUrl.ttlSec 참조.
  Future<ClipMediaUrl> getThumbnailUrl(String id, {int retries = 1}) async {
    try {
      final resp = await _authedRequest(() async => http.get(
            Uri.parse('$_backendUrl/clips/$id/thumbnail/url'),
            headers: await _authHeadersHttp(),
          ));
      if (resp.statusCode == 200) {
        return ClipMediaUrl.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      // 5xx만 retry, 4xx는 영구 에러
      if (retries > 0 && resp.statusCode >= 500) {
        await Future.delayed(const Duration(milliseconds: 500));
        return getThumbnailUrl(id, retries: retries - 1);
      }
      throw BackendException(resp.statusCode, _extractDetail(resp.body));
    } on http.ClientException {
      if (retries > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        return getThumbnailUrl(id, retries: retries - 1);
      }
      rethrow;
    }
  }

  /// 해당 클립의 사람 라벨 목록. 404면 빈 리스트 반환.
  Future<List<BehaviorLabel>> getLabels(String id) async {
    final resp = await _authedRequest(() async => http.get(
          Uri.parse('$_backendUrl/clips/$id/labels'),
          headers: await _authHeadersHttp(),
        ));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as List;
      return body
          .map((e) => BehaviorLabel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (resp.statusCode == 404) return const [];
    throw BackendException(resp.statusCode, _extractDetail(resp.body));
  }

  /// VLM 추론 결과. 204/404면 null 반환.
  Future<BehaviorInference?> getInference(String id) async {
    final resp = await _authedRequest(() async => http.get(
          Uri.parse('$_backendUrl/clips/$id/inference'),
          headers: await _authHeadersHttp(),
        ));
    if (resp.statusCode == 200) {
      if (resp.body.isEmpty || resp.body == 'null') return null;
      final decoded = jsonDecode(resp.body);
      if (decoded == null) return null;
      return BehaviorInference.fromJson(decoded as Map<String, dynamic>);
    }
    if (resp.statusCode == 204 || resp.statusCode == 404) return null;
    throw BackendException(resp.statusCode, _extractDetail(resp.body));
  }

  /// 현재 사용자의 라벨러 여부. 404/501면 null 반환 (미구현 fallback).
  Future<LabelerStatus?> getMyLabelerStatus() async {
    final resp = await _authedRequest(() async => http.get(
          Uri.parse('$_backendUrl/me/is_labeler'),
          headers: await _authHeadersHttp(),
        ));
    if (resp.statusCode == 200) {
      return LabelerStatus.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    if (resp.statusCode == 404 || resp.statusCode == 501) return null;
    throw BackendException(resp.statusCode, _extractDetail(resp.body));
  }

  /// 하이라이트 클립 페이지. cursor-based, 404/501면 empty 반환.
  Future<HighlightsPage> getHighlights({
    DateTime? cursor,
    int limit = 50,
    String? petId,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor.toUtc().toIso8601String();
    if (petId != null) params['pet_id'] = petId;
    final uri = Uri.parse('$_backendUrl/clips/highlights')
        .replace(queryParameters: params);
    final resp = await _authedRequest(() async => http.get(
          uri,
          headers: await _authHeadersHttp(),
        ));
    if (resp.statusCode == 200) {
      return HighlightsPage.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    if (resp.statusCode == 404 || resp.statusCode == 501) {
      return HighlightsPage.empty;
    }
    throw BackendException(resp.statusCode, _extractDetail(resp.body));
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────

  /// 401 응답 시 전역 signOut으로 /login 자동 이동 유도.
  Future<http.Response> _authedRequest(
      Future<http.Response> Function() send) async {
    final resp = await send();
    if (resp.statusCode == 401) {
      await _supabase.auth.signOut();
    }
    return resp;
  }

  /// HTTP 요청용 Bearer 헤더. 기존 동기 authHeaders()와 이름 구분.
  Future<Map<String, String>> _authHeadersHttp() async {
    final token = await _tokenProvider();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  String _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
