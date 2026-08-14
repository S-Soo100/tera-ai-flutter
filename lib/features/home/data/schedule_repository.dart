import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/schedule.dart';

/// 예약 CRUD 실패. 화면이 사유를 보여줄 수 있게 상태 코드를 들고 있는다.
class ScheduleException implements Exception {
  final int statusCode;
  final String detail;

  const ScheduleException(this.statusCode, this.detail);

  /// 요청이 잘못된 경우(400) — 앱이 못 만들 값을 보냈다는 뜻이다.
  bool get isBadRequest => statusCode == 400;

  @override
  String toString() => 'ScheduleException($statusCode): $detail';
}

/// terra-api `schedules` 접근.
///
/// **REST 전용이다.** 테이블에 RLS가 있어 Supabase 직결 INSERT도 통과하지만,
/// `next_run_at`을 서버가 계산하므로 직접 넣으면 예약이 영영 안 돈다
/// (`APP_TIMER_MIST.md` §2). 조회만이라면 직결도 가능하지만, 생성 직후 목록이
/// 서버 계산값과 어긋나지 않도록 읽기도 같은 통로로 맞춘다.
class ScheduleRepository {
  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final SupabaseClient _supabase;

  ScheduleRepository({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    required SupabaseClient supabase,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _supabase = supabase;

  Future<List<Schedule>> list(String deviceId) async {
    final resp = await _send(() async => http.get(
          Uri.parse('$_baseUrl/devices/$deviceId/schedules'),
          headers: await _headers(),
        ));
    _check(resp);
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Schedule> create(
    String deviceId, {
    required ScheduleAction action,
    required ScheduleKind kind,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    Map<String, dynamic>? payload,
    ScheduleGuard? guard,
  }) async {
    final body = Schedule.createBody(
      action: action,
      kind: kind,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      payload: payload,
      guard: guard,
    );
    final resp = await _send(() async => http.post(
          Uri.parse('$_baseUrl/devices/$deviceId/schedules'),
          headers: await _headers(withJson: true),
          body: jsonEncode(body),
        ));
    _check(resp);
    return Schedule.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body) as Map));
  }

  /// 부분 수정. `action`은 서버가 안 받는다(payload만 바꿀 수 있다).
  Future<Schedule> patch(
    String scheduleId,
    Map<String, dynamic> changes,
  ) async {
    final resp = await _send(() async => http.patch(
          Uri.parse('$_baseUrl/schedules/$scheduleId'),
          headers: await _headers(withJson: true),
          body: jsonEncode(changes),
        ));
    _check(resp);
    return Schedule.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body) as Map));
  }

  Future<void> delete(String scheduleId) async {
    final resp = await _send(() async => http.delete(
          Uri.parse('$_baseUrl/schedules/$scheduleId'),
          headers: await _headers(),
        ));
    _check(resp);
  }

  // ── 내부 ────────────────────────────────────────────────────────────────

  /// 401이면 전역 로그아웃. 다른 terra-api 호출과 같은 규칙이다.
  Future<http.Response> _send(Future<http.Response> Function() run) async {
    final resp = await run().timeout(const Duration(seconds: 15));
    if (resp.statusCode == 401) {
      await _supabase.auth.signOut();
    }
    return resp;
  }

  Future<Map<String, String>> _headers({bool withJson = false}) async {
    final token = await _tokenProvider();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (withJson) 'Content-Type': 'application/json',
    };
  }

  void _check(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw ScheduleException(resp.statusCode, _detail(resp.body));
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
