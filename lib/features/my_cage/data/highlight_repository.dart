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

  /// `/highlights/featured` days 상한(서버 le=31 — 초과분은 422).
  static const maxFeaturedDays = 31;

  /// 앱 기본값 한 곳(하드코딩 산개 금지 — 2026-09-11 지시). 하이라이트
  /// 화면은 [defaultFeaturedDays]일치를 tier=all로 받아 day_key로 묶는다.
  /// [defaultTopN]은 서버 기본(응답 `featured.top_n`)과 같은 3.
  static const defaultFeaturedDays = 30;
  static const defaultTopN = 3;

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

  /// 하루(20:00 KST 경계) 단위 ⭐ 대표+후보 — GET /highlights/featured
  /// (계약 2026-09-11). [days]는 오늘 day_key 기준 최근 N개 하루(서버 1..31,
  /// 여기서 클램프), [tier]는 'featured'(대표만)|'all'(후보 포함).
  ///
  /// 저장값이 아니라 조회 시 계산 — 진행 중인 하루는 새 클립에, 지난 하루는
  /// 라벨러 X/✨ 변경에 결과가 바뀐다. 호출부는 화면 진입마다 재조회한다.
  Future<List<NightlyHighlight>> listFeatured({
    int days = defaultFeaturedDays,
    String tier = 'all',
    int topN = defaultTopN,
  }) async {
    days = days.clamp(1, maxFeaturedDays);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_baseUrl/highlights/featured').replace(
      queryParameters: {
        'days': '$days',
        'tier': tier,
        'top_n': '$topN',
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
