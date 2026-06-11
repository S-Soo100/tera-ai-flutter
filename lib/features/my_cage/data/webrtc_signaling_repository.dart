import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'camera_exceptions.dart';

class WebRtcSignalingRepository {
  final String _terraServerUrl;
  final Future<String?> Function() _tokenProvider;
  final SupabaseClient _supabase;

  WebRtcSignalingRepository({
    required String terraServerUrl,
    required Future<String?> Function() tokenProvider,
    required SupabaseClient supabase,
  })  : _terraServerUrl = terraServerUrl,
        _tokenProvider = tokenProvider,
        _supabase = supabase;

  // ── 공개 API ───────────────────────────────────────────────────────────────

  /// GET /cameras/webrtc/config → Map (iceServers, sdpSemantics 등)
  Future<Map<String, dynamic>> fetchConfig() async {
    final resp = await _authedRequest(() async => http.get(
          Uri.parse('$_terraServerUrl/cameras/webrtc/config'),
          headers: await _authHeaders(),
        ));
    _checkStatus(resp);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// POST /cameras/{cameraUuid}/webrtc/offer → (sessionId, answerSdp)
  ///
  /// 504 → [CameraUnresponsiveException]
  /// 502 → [SignalingGatewayException]
  Future<({String sessionId, String answerSdp})> sendOffer(
    String cameraUuid,
    String sdp,
  ) async {
    // 서버가 펌웨어 answer를 timeout_sec(15s)까지 동기 대기하므로
    // http 타임아웃은 그보다 길게 — 504 응답을 받아야 "카메라 응답 없음" 구분 가능
    final resp = await _authedRequest(
      () async => http.post(
        Uri.parse('$_terraServerUrl/cameras/$cameraUuid/webrtc/offer'),
        headers: await _authHeaders(withJson: true),
        body: jsonEncode({
          'sdp': sdp,
          'type': 'offer',
          'timeout_sec': 15.0,
        }),
      ),
      timeoutSec: 25,
    );

    if (resp.statusCode == 504) throw const CameraUnresponsiveException();
    if (resp.statusCode == 502) throw const SignalingGatewayException();
    _checkStatus(resp);

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return (
      sessionId: body['session_id'] as String,
      answerSdp: body['sdp'] as String,
    );
  }

  /// POST /cameras/{cameraUuid}/webrtc/ice — fire-and-forget, 실패 무시
  Future<void> sendIceCandidate(
    String cameraUuid,
    String sessionId,
    Map<String, dynamic> candidateJson,
  ) async {
    try {
      await _authedRequest(() async => http.post(
            Uri.parse('$_terraServerUrl/cameras/$cameraUuid/webrtc/ice'),
            headers: await _authHeaders(withJson: true),
            body: jsonEncode({
              'session_id': sessionId,
              'candidate': candidateJson,
            }),
          ));
    } catch (_) {
      // fire-and-forget
    }
  }

  /// GET /cameras/{cameraUuid}/webrtc/candidates?... → (candidates, nextIndex)
  ///
  /// long-poll 20s → http 타임아웃 30s
  Future<({List<Map<String, dynamic>> candidates, int nextIndex})>
      pollCandidates(
    String cameraUuid,
    String sessionId,
    int sinceIndex,
  ) async {
    final uri = Uri.parse(
      '$_terraServerUrl/cameras/$cameraUuid/webrtc/candidates'
      '?session_id=$sessionId&since_index=$sinceIndex&timeout_sec=20',
    );
    final resp = await _authedRequest(
      () async => http.get(uri, headers: await _authHeaders()),
      timeoutSec: 30,
    );
    _checkStatus(resp);

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final rawList = body['candidates'] as List? ?? [];
    final candidates = rawList
        .map((c) => c as Map<String, dynamic>)
        .toList();
    final nextIndex = body['next_index'] as int? ?? (sinceIndex + rawList.length);

    return (candidates: candidates, nextIndex: nextIndex);
  }

  /// POST /cameras/{cameraUuid}/webrtc/close — best-effort, 모든 예외 무시
  Future<void> closeSession(String cameraUuid, String sessionId) async {
    try {
      await _authedRequest(() async => http.post(
            Uri.parse('$_terraServerUrl/cameras/$cameraUuid/webrtc/close'),
            headers: await _authHeaders(withJson: true),
            body: jsonEncode({'session_id': sessionId}),
          ));
    } catch (_) {
      // best-effort
    }
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────

  /// 401 응답 시 전역 signOut
  Future<http.Response> _authedRequest(
    Future<http.Response> Function() send, {
    int timeoutSec = 15,
  }) async {
    final resp =
        await send().timeout(Duration(seconds: timeoutSec));
    if (resp.statusCode == 401) {
      await _supabase.auth.signOut();
    }
    return resp;
  }

  Future<Map<String, String>> _authHeaders({bool withJson = false}) async {
    final token = await _tokenProvider();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (withJson) 'Content-Type': 'application/json',
    };
  }

  void _checkStatus(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw BackendException(resp.statusCode, _extractDetail(resp.body));
    }
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
