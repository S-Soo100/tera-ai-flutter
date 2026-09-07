import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nightly_highlight.dart';
import 'camera_exceptions.dart';

/// petcam-api 하이라이트(어젯밤 리포트) 조회. 보기 전용 — 확정(사람 판정)은
/// 관리자 라벨러 웹 몫.
///
/// 2026-09-08 owner 결정: 하이라이트는 VLM 행동 라벨이 아니라 **자동 1차
/// 판정 규칙(O/X, `rule_version`) + 사람 확정(`source == 'human'`)**으로 정한다.
/// 그래서 소스가 terra-api `/clips/highlights`에서 petcam-api `/highlights`로
/// 옮겨졌고, terra-server의 `/clips/highlights`는 앱이 더 이상 호출하지 않는다.
/// base URL은 다른 petcam-api 호출과 같은 `EnvConfig.backendUrl` + JWT bearer.
class HighlightRepository {
  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final http.Client _client;

  /// [client]는 테스트 주입용(`package:http/testing.dart`의 MockClient).
  /// 생략하면 실제 클라이언트를 쓴다.
  HighlightRepository({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _client = client ?? http.Client();

  /// 서버가 받는 limit 상한(FastAPI le=100 — 초과분은 422, 2026-09-04 실측).
  /// 계약을 아는 계층이 지킨다: 넘겨받은 limit은 여기서 클램프된다.
  static const maxLimit = 100;

  /// [since] 이후 하이라이트 목록(최신순 가정, 서버 규칙+사람 확정 적용본).
  Future<List<NightlyHighlight>> list(
      {required DateTime since, int limit = 50}) async {
    limit = limit.clamp(1, maxLimit);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_baseUrl/highlights').replace(
      queryParameters: {
        'since': since.toUtc().toIso8601String(),
        'limit': '$limit',
      },
    );
    final resp = await _client.get(uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['highlights'] as List? ?? const []);
      return list
          .map((e) => NightlyHighlight.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (resp.statusCode == 404) return const [];
    throw BackendException(resp.statusCode, resp.body);
  }
}
