import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env_config.dart';
import '../../../core/network/auth_session.dart';

/// 직접 녹화 R2 업로드 — terra-server `/recordings` (합의 결과 2026-10-20,
/// `docs/handoffs/2026-10-20-live-recording-server-requests.md` "합의 결과" 절).
///
/// 흐름: `POST /recordings`(등록 + presigned PUT URL) → 영상·썸네일 PUT →
/// `POST /recordings/{id}/complete`. 삭제는 `DELETE /recordings/{id}`.
/// 재시도·상태 판단은 대기열(`LiveRecordingUploadQueue`)이 하고, 이 저장소는
/// 한 번의 호출과 오류 코드 해석만 맡는다.
///
/// 인증은 [AuthSession] — 401이면 세션을 되살려 **한 번만** 다시 보낸다
/// (만료 토큰 한 번에 로그아웃시키지 않는다, `TerraRestClient`와 같은 규칙).
/// presigned PUT에는 인증 헤더를 붙이지 않는다(서명이 깨진다).
class LiveRecordingUploadRepository {
  LiveRecordingUploadRepository({
    required String baseUrl,
    required AuthSession session,
    required http.Client client,
  })  : _baseUrl = baseUrl,
        _session = session,
        _http = client;

  final String _baseUrl;
  final AuthSession _session;
  final http.Client _http;

  static const _restTimeout = Duration(seconds: 15);

  /// 영상 PUT 한도 — 30MB를 느린 망에서 올려도 되게 넉넉히.
  static const _putTimeout = Duration(minutes: 10);

  /// 등록. 같은 `client_id`면 서버가 같은 행 + 새 URL을 돌려준다(200).
  /// 23시간 30분 넘은 pending이면 새 `recording_id`(201).
  Future<RecordingRegistration> register(RecordingRegisterRequest req) async {
    final resp = await _rest(() async => _http.post(
          Uri.parse('$_baseUrl/recordings'),
          headers: await _headers(json: true),
          body: jsonEncode(req.toJson()),
        ));
    _log('POST /recordings', resp.statusCode);
    _throwUnlessOk(resp);
    final body = _decodeMap(resp);
    final reg = RecordingRegistration.tryParse(body);
    if (reg == null) {
      throw RecordingApiException(resp.statusCode, 'bad_response');
    }
    debugPrint('[rec-upload] registered rid=${reg.recordingId} '
        'status=${reg.status} has_video_url=${reg.videoUploadUrl != null} '
        'has_thumb_url=${reg.thumbUploadUrl != null}');
    return reg;
  }

  /// presigned PUT으로 파일을 올린다(스트리밍 — 30MB를 메모리에 올리지 않는다).
  /// [abort]가 끝나면 전송을 끊는다(삭제·계정 전환).
  Future<void> putFile(Uri url, String path, String contentType,
      {required String label, Future<void>? abort}) async {
    final file = File(path);
    final length = await file.length();
    final req = http.AbortableStreamedRequest('PUT', url, abortTrigger: abort)
      ..headers['Content-Type'] = contentType
      ..contentLength = length;
    final sending = _http.send(req);
    unawaited(req.sink
        .addStream(file.openRead())
        .then((_) => req.sink.close(), onError: (Object _) => req.sink.close()));
    await _finishPut(sending, label);
  }

  Future<void> putBytes(Uri url, Uint8List bytes, String contentType,
      {required String label, Future<void>? abort}) async {
    final req = http.AbortableRequest('PUT', url, abortTrigger: abort)
      ..headers['Content-Type'] = contentType
      ..bodyBytes = bytes;
    await _finishPut(_http.send(req), label);
  }

  Future<void> _finishPut(
      Future<http.StreamedResponse> sending, String label) async {
    final streamed = await sending.timeout(_putTimeout);
    final resp = await http.Response.fromStream(streamed);
    _log('PUT $label', resp.statusCode);
    _throwUnlessOk(resp);
  }

  /// 업로드 확인. 반환은 서버 status(`ready`).
  /// 409 `upload_missing`이면 [RecordingApiException.code]로 알 수 있다.
  Future<String?> complete(String recordingId) async {
    final resp = await _rest(() async => _http.post(
          Uri.parse('$_baseUrl/recordings/$recordingId/complete'),
          headers: await _headers(),
        ));
    _log('POST /recordings/{id}/complete', resp.statusCode);
    _throwUnlessOk(resp);
    final status = _decodeMap(resp)['status'];
    return status is String ? status : null;
  }

  /// 삭제. 404(이미 없음·남의 것)는 성공으로 본다.
  Future<void> delete(String recordingId) async {
    final resp = await _rest(() async => _http.delete(
          Uri.parse('$_baseUrl/recordings/$recordingId'),
          headers: await _headers(),
        ));
    _log('DELETE /recordings/{id}', resp.statusCode);
    if (resp.statusCode == 404) return;
    _throwUnlessOk(resp);
  }

  Future<http.Response> _rest(Future<http.Response> Function() send) async {
    var resp = await send().timeout(_restTimeout);
    if (resp.statusCode == 401) {
      _log('401 → 세션 갱신 후 1회 재시도', resp.statusCode);
      if (await _session.recoverFromUnauthorized()) {
        resp = await send().timeout(_restTimeout);
      }
    }
    return resp;
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _session.accessToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static void _throwUnlessOk(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw RecordingApiException(resp.statusCode, errorCodeOf(resp.body));
  }

  static Map<String, Object?> _decodeMap(http.Response resp) {
    if (resp.body.isEmpty) return const {};
    try {
      final d = jsonDecode(resp.body);
      if (d is Map<String, Object?>) return d;
    } catch (_) {}
    // 2xx인데 JSON이 아니다 — 캡티브 포털·프록시. 성공으로 삼키지 않는다.
    throw RecordingApiException(resp.statusCode, 'non_json');
  }

  /// 서버 오류 본문에서 코드를 꺼낸다:
  /// `{"detail":{"code":"upload_missing"}}` / `{"detail":"recording_quota_exceeded"}`
  /// / `{"code":"..."}`. 없으면 null.
  @visibleForTesting
  static String? errorCodeOf(String body) {
    try {
      final d = jsonDecode(body);
      if (d is! Map) return null;
      final detail = d['detail'];
      if (detail is Map && detail['code'] is String) {
        return detail['code'] as String;
      }
      if (detail is String && RegExp(r'^[a-z_]+$').hasMatch(detail)) {
        return detail;
      }
      final code = d['code'];
      return code is String ? code : null;
    } catch (_) {
      return null;
    }
  }

  static void _log(String what, int code) =>
      debugPrint('[rec-upload] $what → $code');
}

/// `/recordings` 실패(2xx 밖). [code]는 서버 오류 코드(있을 때).
class RecordingApiException implements Exception {
  const RecordingApiException(this.statusCode, [this.code]);

  final int statusCode;
  final String? code;

  static const uploadMissing = 'upload_missing';
  static const quotaExceeded = 'recording_quota_exceeded';

  bool get isQuota => statusCode == 409 && code == quotaExceeded;
  bool get isUploadMissing => statusCode == 409 && code == uploadMissing;

  @override
  String toString() => 'RecordingApiException($statusCode, $code)';
}

class RecordingRegisterRequest {
  const RecordingRegisterRequest({
    required this.cameraId,
    required this.clientId,
    required this.startedAt,
    required this.durationMs,
    required this.sizeBytes,
    required this.hasThumbnail,
    this.width,
    this.height,
  });

  final String cameraId;
  final String clientId;
  final DateTime startedAt;
  final int durationMs;
  final int sizeBytes;
  final bool hasThumbnail;
  final int? width;
  final int? height;

  Map<String, Object?> toJson() => {
        'camera_id': cameraId,
        'client_id': clientId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
        'width': width,
        'height': height,
        'has_thumbnail': hasThumbnail,
      };
}

/// 등록 응답. `status == ready`면 URL·만료가 null — 업로드를 건너뛴다.
class RecordingRegistration {
  const RecordingRegistration({
    required this.recordingId,
    required this.status,
    this.videoUploadUrl,
    this.thumbUploadUrl,
    this.expiresAt,
  });

  final String recordingId;
  final String status;
  final Uri? videoUploadUrl;
  final Uri? thumbUploadUrl;
  final DateTime? expiresAt;

  bool get isReady => status == 'ready';

  static RecordingRegistration? tryParse(Map<String, Object?> j) {
    final id = j['recording_id'];
    if (id is! String || id.isEmpty) return null;
    final status = j['status'];
    Uri? url(Object? v) => v is String && v.isNotEmpty ? Uri.tryParse(v) : null;
    final exp = j['expires_at'];
    return RecordingRegistration(
      recordingId: id,
      status: status is String ? status : 'pending',
      videoUploadUrl: url(j['video_upload_url']),
      thumbUploadUrl: url(j['thumb_upload_url']),
      expiresAt: exp is String ? DateTime.tryParse(exp) : null,
    );
  }
}

/// 업로드 전용 HTTP 클라이언트 — 테스트가 가짜로 바꿔 끼운다.
final liveRecordingHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final liveRecordingUploadRepositoryProvider =
    Provider<LiveRecordingUploadRepository>((ref) =>
        LiveRecordingUploadRepository(
          baseUrl: EnvConfig.terraServerUrl,
          session: ref.watch(authSessionProvider),
          client: ref.watch(liveRecordingHttpClientProvider),
        ));
