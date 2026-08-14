import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';

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
/// Bearer 토큰, 15초 타임아웃, **401이면 전역 로그아웃**(다른 terra-api 호출과
/// 같은 규칙), 2xx 밖은 [TerraRestException].
///
/// 반환은 디코드된 JSON([Object?])이다 — 모양(List/Map)은 호출부가 안다.
class TerraRestClient {
  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final SupabaseClient _supabase;

  TerraRestClient({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    required SupabaseClient supabase,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _supabase = supabase;

  Future<Object?> get(String path) async =>
      _run(() async => http.get(_uri(path), headers: await _headers()));

  /// [body]가 null이면 본문 없는 POST다(예: `/lcd/clear`).
  Future<Object?> post(String path, [Map<String, dynamic>? body]) async =>
      _run(() async => http.post(
            _uri(path),
            headers: await _headers(withJson: body != null),
            body: body == null ? null : jsonEncode(body),
          ));

  Future<Object?> patch(String path, Map<String, dynamic> body) async =>
      _run(() async => http.patch(
            _uri(path),
            headers: await _headers(withJson: true),
            body: jsonEncode(body),
          ));

  Future<void> delete(String path) async =>
      _run(() async => http.delete(_uri(path), headers: await _headers()));

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Object?> _run(Future<http.Response> Function() send) async {
    final resp = await send().timeout(const Duration(seconds: 15));
    if (resp.statusCode == 401) {
      await _supabase.auth.signOut();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TerraRestException(resp.statusCode, _detail(resp.body));
    }
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      // 2xx인데 JSON이 아니면(빈 200 등) 본문 없음으로 취급한다.
      return null;
    }
  }

  Future<Map<String, String>> _headers({bool withJson = false}) async {
    final token = await _tokenProvider();
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
    tokenProvider: () async =>
        Supabase.instance.client.auth.currentSession?.accessToken,
    supabase: Supabase.instance.client,
  );
});
