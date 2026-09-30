import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/auth_session.dart';

import 'camera_exceptions.dart';

class WebRtcSignalingRepository {
  final String _terraServerUrl;
  final AuthSession _session;

  WebRtcSignalingRepository({
    required String terraServerUrl,
    required AuthSession session,
  })  : _terraServerUrl = terraServerUrl,
        _session = session;

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

  /// POST /cameras/{cameraUuid}/webrtc/offer → (sessionId, answerSdp,
  /// offerAttempts, answerMs)
  ///
  /// `offerAttempts`·`answerMs`는 2026-09-23 서버 추가(APP_WEBRTC.md §4.2.1) —
  /// 카메라가 답을 안 하면 서버가 7초씩 최대 3회 다시 보내는데, 앱에는 느린
  /// 한 번의 호출로만 보인다. 1이면 이후 실패는 ICE/NAT, 2 이상이면 펌웨어.
  /// 구 서버는 안 주므로 null.
  ///
  /// 라이브 시청 제한(2026-09-30): [viewerId](설치 ID)로 한 기기 판정,
  /// [takeover]는 사용자가 "이 기기로 시청"을 고른 요청에만 true. 구 서버는
  /// 모르는 필드를 무시한다. `liveUntil`은 서버가 라이브를 끝낼 시각(UTC,
  /// 구 서버 null).
  ///
  /// 504 → [CameraUnresponsiveException]
  /// 502 → [SignalingGatewayException]
  /// 409 → [LiveInUseException]
  /// 429 → [LiveCooldownException] / [LiveRateLimitedException]
  Future<
      ({
        String sessionId,
        String answerSdp,
        int? offerAttempts,
        int? answerMs,
        DateTime? liveUntil,
      })> sendOffer(
    String cameraUuid,
    String sdp, {
    String? viewerId,
    bool takeover = false,
  }) async {
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
          if (viewerId != null) 'viewer_id': viewerId,
          if (takeover) 'takeover': true,
        }),
      ),
      timeoutSec: 25,
    );

    if (resp.statusCode == 504) throw const CameraUnresponsiveException();
    if (resp.statusCode == 502) throw const SignalingGatewayException();
    final limit = liveLimitException(resp);
    if (limit != null) throw limit;
    _checkStatus(resp);

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final until = body['live_until'];
    return (
      sessionId: body['session_id'] as String,
      answerSdp: body['sdp'] as String,
      offerAttempts: (body['offer_attempts'] as num?)?.toInt(),
      answerMs: (body['answer_ms'] as num?)?.toInt(),
      liveUntil: until is String ? DateTime.tryParse(until) : null,
    );
  }

  /// offer 409·429 응답을 시청 제한 예외로 바꾼다. 해당 없으면 null.
  /// body `{"detail": {"code": ..., "retry_after": N}}`.
  /// 구 서버 429는 detail이 문자열이다 — 시간당 상한(rate_limited)으로 본다.
  @visibleForTesting
  static Exception? liveLimitException(http.Response resp) {
    if (resp.statusCode != 409 && resp.statusCode != 429) return null;
    Map<String, dynamic> detail = const {};
    try {
      final d = (jsonDecode(resp.body) as Map)['detail'];
      if (d is Map<String, dynamic>) detail = d;
    } catch (_) {}
    final code = detail['code'];
    if (resp.statusCode == 409) {
      // 다른 409(예: 등록 충돌)는 offer에서 나오지 않지만, code가 다르면 건드리지 않는다.
      if (code != 'live_in_use') return null;
      return const LiveInUseException();
    }
    final secs = (detail['retry_after'] as num?)?.toInt() ??
        int.tryParse(resp.headers['retry-after'] ?? '') ??
        60;
    final after = Duration(seconds: secs < 1 ? 1 : secs);
    return code == 'live_cooldown'
        ? LiveCooldownException(after)
        : LiveRateLimitedException(after);
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
    final candidates = rawList.map((c) => c as Map<String, dynamic>).toList();
    final nextIndex =
        body['next_index'] as int? ?? (sinceIndex + rawList.length);

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

  /// 401이면 세션을 되살려 **한 번 더** 보낸다. 로그아웃은 refresh 자체가
  /// 거부당했을 때만 일어난다([AuthSession]) — 만료 토큰 한 번에 자동 로그인을
  /// 날리던 규칙의 교체(2026-09-21).
  Future<http.Response> _authedRequest(
    Future<http.Response> Function() send, {
    int timeoutSec = 15,
  }) async {
    final resp = await send().timeout(Duration(seconds: timeoutSec));
    if (resp.statusCode != 401) return resp;
    if (!await _session.recoverFromUnauthorized()) return resp;
    return send().timeout(Duration(seconds: timeoutSec));
  }

  Future<Map<String, String>> _authHeaders({bool withJson = false}) async {
    final token = await _session.accessToken();
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
