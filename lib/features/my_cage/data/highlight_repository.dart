import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../domain/nightly_highlight.dart';
import 'camera_exceptions.dart';

/// `/highlights` 한 페이지의 통과 클립 참조 — 전체 영상 목록용(정책 v2).
/// [nextCursor]는 서버 불투명 커서라 앱이 해석·조립하지 않는다.
/// [oldestStartedAt]은 이 페이지에서 가장 오래된 항목 시각(UTC) — 앱측
/// 범위 재필터가 "더 넘길 필요가 있는지" 판단하는 데 쓴다.
typedef PassedClipRefPage = ({
  List<String> clipIds,
  List<DateTime> startedAts,
  DateTime? oldestStartedAt,
  String? nextCursor,
  bool hasMore,
});

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
  /// 화면은 [defaultFeaturedDays]일치를 받아 day_key로 묶는다.
  static const defaultFeaturedDays = 30;

  /// [since] 이후 하이라이트 목록(최신순 가정, 서버 규칙+사람 확정 적용본).
  Future<List<NightlyHighlight>> list({
    required String cameraId,
    required DateTime since,
    int limit = 50,
  }) async {
    limit = limit.clamp(1, maxLimit);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_baseUrl/highlights').replace(
      queryParameters: {
        'camera_id': cameraId,
        'since': since.toUtc().toIso8601String(),
        'limit': '$limit',
      },
    );
    final resp = await _client.get(uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return _highlightsForCamera(body, cameraId, '/highlights');
    }
    if (resp.statusCode == 404) return const [];
    throw BackendException(resp.statusCode, resp.body);
  }

  /// 전체 영상 목록 기본 페이지 크기(기존 motion_clips 피드와 동일).
  static const defaultPassedPageSize = 60;

  /// 규칙 O + 사람 확정 O **전부**를 최신순 cursor 페이지로 — 카메라 탭 전체
  /// 영상 목록(정책 v2, 2026-09-19). [since] 포함 하한, [until] 미포함 상한
  /// (서버 미배포 동안은 무시된다 — 호출부가 상한을 한 번 더 거른다).
  Future<PassedClipRefPage> listPassedPage({
    required String cameraId,
    DateTime? since,
    DateTime? until,
    String? cursor,
    int limit = defaultPassedPageSize,
  }) async {
    limit = limit.clamp(1, maxLimit);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_baseUrl/highlights').replace(
      queryParameters: {
        'camera_id': cameraId,
        'limit': '$limit',
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (until != null) 'until': until.toUtc().toIso8601String(),
        if (cursor != null) 'cursor': cursor,
      },
    );
    final resp = await _client.get(uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    const PassedClipRefPage empty = (
      clipIds: <String>[],
      startedAts: <DateTime>[],
      oldestStartedAt: null,
      nextCursor: null,
      hasMore: false,
    );
    if (resp.statusCode == 404) return empty;
    if (resp.statusCode != 200) {
      throw BackendException(resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw BackendException(resp.statusCode, 'Unexpected body: ${resp.body}');
    }
    final body = decoded;
    final responseCameraId = body['camera_id'];
    if (responseCameraId != null && responseCameraId != cameraId) {
      debugPrint('[passed-clips] discarded mismatched response: '
          'requested=$cameraId, response=$responseCameraId');
      return empty;
    }
    final ids = <String>[];
    final times = <DateTime>[];
    final rawList = body['highlights'];
    for (final raw in rawList is List ? rawList : const <Object?>[]) {
      if (raw is! Map<String, dynamic>) continue;
      final rawId = raw['clip_id'];
      final id = rawId is String ? rawId : '';
      final at = DateTime.tryParse('${raw['started_at']}')?.toUtc();
      if (id.isEmpty || at == null) continue;
      if (responseCameraId == null && raw['camera_id'] != cameraId) continue;
      ids.add(id);
      times.add(at);
    }
    final next = body['next_cursor'];
    return (
      clipIds: ids,
      startedAts: times,
      oldestStartedAt: times.isEmpty
          ? null
          : times.reduce((a, b) => a.isBefore(b) ? a : b),
      nextCursor: next is String && next.isNotEmpty ? next : null,
      hasMore: body['has_more'] == true,
    );
  }

  /// 하루(20:00 KST 경계) 단위 ⭐ 대표+후보 — GET /highlights/featured
  /// (계약 2026-09-11). [days]는 오늘 day_key 기준 최근 N개 하루(서버 1..31,
  /// 여기서 클램프), [tier]는 'featured'(대표만)|'all'(후보 포함).
  ///
  /// **top_n은 보내지 않는다**(기준 개정 2026-09-11 후속): 새 기준은 하루
  /// 상한 없이 "같은 시간대(KST 시) 안 최대 3개"를 서버가 계산하는데,
  /// top_n을 보내면 구 방식의 하루 상한이 다시 걸린다.
  ///
  /// 저장값이 아니라 조회 시 계산 — 진행 중인 하루는 새 클립에, 지난 하루는
  /// 라벨러 X/✨ 변경에 결과가 바뀐다. 호출부는 화면 진입마다 재조회한다.
  Future<List<NightlyHighlight>> listFeatured({
    required String cameraId,
    int days = defaultFeaturedDays,
    String tier = 'all',
  }) async {
    days = days.clamp(1, maxFeaturedDays);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_baseUrl/highlights/featured').replace(
      queryParameters: {
        'camera_id': cameraId,
        'days': '$days',
        'tier': tier,
      },
    );
    final resp = await _client.get(uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return _highlightsForCamera(body, cameraId, '/highlights/featured');
    }
    if (resp.statusCode == 404) return const [];
    throw BackendException(resp.statusCode, resp.body);
  }

  /// 배포 전 서버는 최상단 `camera_id`가 null이고 소유 카메라 전체를 돌려줄
  /// 수 있다. 그때만 앱에서 한 번 더 거른다. 값이 있는데 요청과 다르면
  /// 카메라 전환 중 도착한 잘못된 응답이므로 전체를 버린다.
  List<NightlyHighlight> _highlightsForCamera(
    Map<String, dynamic> body,
    String requestedCameraId,
    String endpoint,
  ) {
    final responseCameraId = body['camera_id'];
    if (responseCameraId != null && responseCameraId != requestedCameraId) {
      debugPrint(
        '[highlights] discarded mismatched $endpoint response: '
        'requested=$requestedCameraId, response=$responseCameraId',
      );
      return const [];
    }

    final highlights = (body['highlights'] as List? ?? const [])
        .map((e) => NightlyHighlight.fromJson(e as Map<String, dynamic>));
    if (responseCameraId == null) {
      return highlights
          .where((highlight) => highlight.cameraId == requestedCameraId)
          .toList();
    }
    return highlights.toList();
  }
}
