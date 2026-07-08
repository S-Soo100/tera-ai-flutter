import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nightly_highlight.dart';
import 'camera_exceptions.dart';

/// terra-api 하이라이트(어젯밤 리포트) + 라벨 확인(GT). motion_clip_repository와
/// 동일한 terra-api base + JWT 패턴.
class HighlightRepository {
  final String _terraApiUrl;
  final Future<String?> Function() _tokenProvider;

  HighlightRepository({
    required String terraApiUrl,
    required Future<String?> Function() tokenProvider,
  })  : _terraApiUrl = terraApiUrl,
        _tokenProvider = tokenProvider;

  /// [since] 이후 하이라이트 목록(최신순 가정, 서버 필터/억제셋 적용본).
  Future<List<NightlyHighlight>> list(
      {required DateTime since, int limit = 50}) async {
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

  /// 확인/정정 GT 제출 (POST /clips/{id}/labels, behavior_labels UPSERT).
  /// 👍=vlm_action 그대로, 정정=선택 action. 오탐(👎)은 호출하지 않는다.
  Future<void> submitLabel(String clipId, String action,
      {String? lickTarget, String? note}) async {
    final token = await _tokenProvider();
    final resp = await http.post(
      Uri.parse('$_terraApiUrl/clips/$clipId/labels'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action,
        if (lickTarget != null) 'lick_target': lickTarget,
        if (note != null) 'note': note,
      }),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) return;
    throw BackendException(resp.statusCode, resp.body);
  }
}
