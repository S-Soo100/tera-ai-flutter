import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/camera.dart';
import '../domain/camera_register_input.dart';
import '../domain/test_connection_result.dart';
import 'camera_exceptions.dart';

class CameraRepository {
  final SupabaseClient _supabase;
  final String _backendUrl;
  final Future<String?> Function() _tokenProvider;

  CameraRepository({
    required SupabaseClient supabase,
    required String backendUrl,
    required Future<String?> Function() tokenProvider,
  })  : _supabase = supabase,
        _backendUrl = backendUrl,
        _tokenProvider = tokenProvider;

  // ── Supabase 직결 ──────────────────────────────────────────────────────────

  Future<List<Camera>> listAll() async {
    final rows = await _supabase
        .from('cameras')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Camera.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Camera?> getById(String id) async {
    final rows = await _supabase
        .from('cameras')
        .select()
        .eq('id', id)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Camera.fromJson(list.first as Map<String, dynamic>);
  }

  Future<List<Camera>> listByPet(String petId) async {
    final rows = await _supabase
        .from('cameras')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Camera.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(String id) async {
    await _supabase.from('cameras').delete().eq('id', id);
  }

  // ── Backend API (JWT 필요) ─────────────────────────────────────────────────

  /// RTSP 연결 테스트. 200(성공) 또는 400(실패) 모두 TestConnectionResult로 파싱.
  Future<TestConnectionResult> testConnection(
      CameraRegisterInput input) async {
    final resp = await http.post(
      Uri.parse('$_backendUrl/cameras/test-connection'),
      headers: await _authHeaders(withJson: true),
      body: jsonEncode(input.toJson()),
    );
    if (resp.statusCode == 200 || resp.statusCode == 400) {
      return TestConnectionResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw BackendException(resp.statusCode, _extractDetail(resp.body));
  }

  /// 카메라 등록. 비밀번호 Fernet 암호화 + DB INSERT는 backend가 처리.
  Future<Camera> register(CameraRegisterInput input) async {
    final resp = await http.post(
      Uri.parse('$_backendUrl/cameras'),
      headers: await _authHeaders(withJson: true),
      body: jsonEncode(input.toJson()),
    );
    if (resp.statusCode == 201) {
      return Camera.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    if (resp.statusCode == 409) {
      throw CameraConflictException(_extractDetail(resp.body));
    }
    throw BackendException(resp.statusCode, _extractDetail(resp.body));
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders(
      {bool withJson = false}) async {
    final token = await _tokenProvider();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (withJson) 'Content-Type': 'application/json',
    };
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
