import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'auth_session.dart';

/// terra-api REST 실패. 화면이 사유를 보여줄 수 있게 상태 코드를 들고 있는다.
class TerraRestException implements Exception {
  final int statusCode;
  final String detail;

  const TerraRestException(this.statusCode, this.detail);

  /// 요청이 잘못된 경우(400) — 앱이 못 만들 값을 보냈다는 뜻이다.
  bool get isBadRequest => statusCode == 400;

  @override
  String toString() => 'TerraRestException($statusCode): $detail';
}

/// terra-api(`EnvConfig.terraServerUrl`) 공통 REST 통로.
///
/// 예약(`ScheduleRepository`)·LCD(`LcdRepository`)가 공유한다. 규칙은 하나다 —
/// Bearer 토큰, 15초 타임아웃, **401이면 세션을 되살려 한 번 더**([AuthSession]),
/// 2xx 밖은 [TerraRestException].
///
/// 반환은 디코드된 JSON([Object?])이다 — 모양(List/Map)은 호출부가 안다.
class TerraRestClient {
  final String _baseUrl;
  final AuthSession _session;
  final http.Client _http;

  /// [httpClient]는 테스트 주입용이다 — 안 주면 매 호출이 새 연결을 쓴다
  /// (기존 top-level `http.get` 동작과 같다).
  TerraRestClient({
    required String baseUrl,
    required AuthSession session,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _session = session,
        _http = httpClient ?? http.Client();

  Future<Object?> get(String path) async =>
      _run(() async => _http.get(_uri(path), headers: await _headers()));

  /// [body]가 null이면 본문 없는 POST다(예: `/lcd/clear`).
  Future<Object?> post(String path, [Map<String, dynamic>? body]) async =>
      _run(() async => _http.post(
            _uri(path),
            headers: await _headers(withJson: body != null),
            body: body == null ? null : jsonEncode(body),
          ));

  Future<Object?> patch(String path, Map<String, dynamic> body) async =>
      _run(() async => _http.patch(
            _uri(path),
            headers: await _headers(withJson: true),
            body: jsonEncode(body),
          ));

  Future<void> delete(String path) async =>
      _run(() async => _http.delete(_uri(path), headers: await _headers()));

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Object?> _run(Future<http.Response> Function() send) async {
    var resp = await send().timeout(const Duration(seconds: 15));
    // 만료 토큰 한 번에 로그아웃시키지 않는다 — 되살려 한 번 더 보낸다.
    // 되살리지 못한 게 "세션이 끝나서"라면 [AuthSession]이 이미 로그아웃했다.
    if (resp.statusCode == 401 && await _session.recoverFromUnauthorized()) {
      resp = await send().timeout(const Duration(seconds: 15));
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TerraRestException(resp.statusCode, _detail(resp.body));
    }
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      // 2xx인데 본문이 JSON이 아니다 — 캡티브 포털/프록시가 낀 응답이다.
      // null로 삼키면 예약 목록이 "예약 없음" 같은 **거짓 정상 화면**이 되므로
      // 에러로 올린다(추출 전 ScheduleRepository도 여기서 던졌다).
      throw TerraRestException(resp.statusCode, 'non-JSON response body');
    }
  }

  Future<Map<String, String>> _headers({bool withJson = false}) async {
    final token = await _session.accessToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (withJson) 'Content-Type': 'application/json',
    };
  }

  String _detail(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {
      // 본문이 JSON이 아니면 그대로 쓴다.
    }
    return body;
  }
}

/// 앱 전역 terra-api 클라이언트. 예약·LCD provider가 같은 것을 쓴다.
final terraRestClientProvider = Provider<TerraRestClient>((ref) {
  return TerraRestClient(
    baseUrl: EnvConfig.terraServerUrl,
    session: ref.watch(authSessionProvider),
  );
});
