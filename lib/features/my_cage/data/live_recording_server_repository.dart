import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/network/auth_session.dart';
import '../domain/recording_item.dart';
import 'live_recording_upload_repository.dart';

/// keyset 커서 — `(started_at, id)` 내림차순의 마지막 행.
typedef RecordingCursor = ({DateTime startedAt, String id});

/// 한 페이지 행 읽기(테스트가 바꿔 끼운다).
typedef RecordingRowsLoader = Future<List<Map<String, Object?>>> Function(
    {RecordingCursor? before, required int limit});

/// 서버에 올라간 직접 녹화 읽기 — 다른 폰·재설치 후에도 보이게(계획 F단계).
///
/// - 목록: Supabase 직결 SELECT `live_recordings`(`status='ready'`, RLS 본인만,
///   `(started_at, id)` 내림차순 keyset — 합의 결과 2026-10-20). 계정당 최대
///   50개라 한 번에 전부 받는다(페이지는 안전장치).
/// - 재생·썸네일: terra-server `GET /recordings/{id}/url`·
///   `/recordings/{id}/thumbnail/url` → `{url, expires_in: 3600}`(클립과 같은 방식).
///   401은 세션을 되살려 한 번만 다시 보낸다.
class LiveRecordingServerRepository {
  LiveRecordingServerRepository({
    required RecordingRowsLoader loadRows,
    required String baseUrl,
    required AuthSession session,
    required http.Client client,
  })  : _loadRows = loadRows,
        _baseUrl = baseUrl,
        _session = session,
        _http = client;

  final RecordingRowsLoader _loadRows;
  final String _baseUrl;
  final AuthSession _session;
  final http.Client _http;

  static const pageSize = 100;

  /// 페이지를 몇 번까지 넘길지(계정 한도 50 — 넘으면 서버 계약이 바뀐 것).
  static const _maxPages = 10;
  static const _timeout = Duration(seconds: 15);

  /// Supabase 직결 행 읽기.
  static RecordingRowsLoader supabaseLoader(SupabaseClient Function() client) =>
      ({RecordingCursor? before, required int limit}) async {
        var q = client()
            .from('live_recordings')
            .select(ServerLiveRecording.columns)
            .eq('status', 'ready');
        if (before != null) {
          final stamp = before.startedAt.toUtc().toIso8601String();
          // id는 서버 행에서 온 UUID — 사용자 입력이 아니지만 거른다.
          if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(before.id)) {
            throw ArgumentError.value(before.id, 'before.id');
          }
          q = q.or('started_at.lt.$stamp,'
              'and(started_at.eq.$stamp,id.lt.${before.id})');
        }
        final rows = await q
            .order('started_at', ascending: false)
            .order('id', ascending: false)
            .limit(limit);
        return [for (final r in rows) Map<String, Object?>.from(r)];
      };

  /// 이 계정의 `ready` 녹화 전부(최신순).
  Future<List<ServerLiveRecording>> listReady() async {
    final out = <ServerLiveRecording>[];
    RecordingCursor? before;
    for (var page = 0; page < _maxPages; page++) {
      final rows = await _loadRows(before: before, limit: pageSize);
      for (final row in rows) {
        final r = ServerLiveRecording.tryFromJson(row);
        if (r != null) out.add(r);
      }
      if (rows.length < pageSize) break;
      final last = ServerLiveRecording.tryFromJson(rows.last);
      if (last == null) break;
      before = (startedAt: last.startedAt, id: last.id);
    }
    debugPrint('[rec-feed] server list ready=${out.length}');
    return List.unmodifiable(out);
  }

  /// 재생 presigned URL. 실패는 [RecordingApiException].
  Future<String> playbackUrl(String id) async {
    final url = await _url('/recordings/$id/url', 'url');
    if (url == null) throw const RecordingApiException(404, 'not_found');
    return url;
  }

  /// 썸네일 presigned URL. 썸네일이 없으면(404) null.
  Future<String?> thumbnailUrl(String id) =>
      _url('/recordings/$id/thumbnail/url', 'thumbnail');

  Future<String?> _url(String path, String label) async {
    Future<http.Response> send() async {
      final token = await _session.accessToken();
      return _http.get(Uri.parse('$_baseUrl$path'), headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }).timeout(_timeout);
    }

    var resp = await send();
    if (resp.statusCode == 401 && await _session.recoverFromUnauthorized()) {
      resp = await send();
    }
    // URL·토큰은 남기지 않는다.
    debugPrint('[rec-feed] GET $label url → ${resp.statusCode}');
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw RecordingApiException(resp.statusCode);
    }
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['url'] is String) return body['url'] as String;
    } catch (_) {}
    throw RecordingApiException(resp.statusCode, 'bad_response');
  }
}

final liveRecordingServerRepositoryProvider =
    Provider<LiveRecordingServerRepository>(
        (ref) => LiveRecordingServerRepository(
              loadRows: LiveRecordingServerRepository.supabaseLoader(
                  () => Supabase.instance.client),
              baseUrl: EnvConfig.terraServerUrl,
              session: ref.watch(authSessionProvider),
              client: ref.watch(liveRecordingHttpClientProvider),
            ));
