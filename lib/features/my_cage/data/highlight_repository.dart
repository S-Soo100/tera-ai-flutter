import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nightly_highlight.dart';
import 'camera_exceptions.dart';

/// terra-api 하이라이트(어젯밤 리포트) 조회. 보기 전용 — 라벨링(GT)은 관리자
/// 라벨러 웹 몫. motion_clip_repository와 동일한 terra-api base + JWT 패턴.
class HighlightRepository {
  final String _terraApiUrl;
  final Future<String?> Function() _tokenProvider;

  HighlightRepository({
    required String terraApiUrl,
    required Future<String?> Function() tokenProvider,
  })  : _terraApiUrl = terraApiUrl,
        _tokenProvider = tokenProvider;

  /// 서버가 받는 limit 상한(FastAPI le=100 — 초과분은 422, 2026-09-04 실측).
  /// 계약을 아는 계층이 지킨다: 넘겨받은 limit은 여기서 클램프된다.
  static const maxLimit = 100;

  /// [since] 이후 하이라이트 목록(최신순 가정, 서버 필터/억제셋 적용본).
  Future<List<NightlyHighlight>> list(
      {required DateTime since, int limit = 50}) async {
    limit = limit.clamp(1, maxLimit);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_terraApiUrl/clips/highlights').replace(
      queryParameters: {
        'since': since.toUtc().toIso8601String(),
        'limit': '$limit',
      },
    );
    final resp = await http.get(uri,
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
