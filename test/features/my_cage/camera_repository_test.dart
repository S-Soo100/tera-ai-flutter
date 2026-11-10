import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';

class _Session implements AuthSession {
  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> recoverFromUnauthorized() async => false;
}

void main() {
  late List<Map<String, Object?>> rows;
  late SupabaseClient client;
  late CameraRepository repo;

  setUp(() {
    rows = [];
    client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async => http.Response(
            jsonEncode(rows), 200,
            request: request, headers: {'content-type': 'application/json'})));
    repo = CameraRepository(
        supabase: client,
        rest: TerraRestClient(
            baseUrl: 'https://terra.test',
            session: _Session(),
            httpClient: MockClient((_) async => http.Response('{}', 200))));
  });
  tearDown(() => client.dispose());

  // 2026-11-10 서버 계약: 다른 계정이 같은 보드를 등록한 뒤 옛 행이 24시간+
  // 오프라인이면 superseded_at이 찍힌다 — 해제는 아니지만 목록에서 숨긴다.
  test('listAll은 해제·다른 계정으로 넘어간 카메라를 뺀다', () async {
    rows = [
      {'id': 'live', 'camera_id': 'p4cam-1'},
      {'id': 'gone', 'camera_id': 'p4cam-2', 'unlinked_at': '2026-11-01T00:00:00Z'},
      {
        'id': 'taken',
        'camera_id': 'p4cam-3',
        'superseded_at': '2026-11-10T03:40:00Z'
      },
    ];
    expect((await repo.listAll()).map((c) => c.id), ['live']);
  });

  test('getById는 다른 계정으로 넘어간 카메라면 null', () async {
    rows = [
      {'id': 'taken', 'camera_id': 'p4cam-3', 'superseded_at': '2026-11-10T03:40:00Z'}
    ];
    expect(await repo.getById('taken'), isNull);
    rows = [
      {'id': 'live', 'camera_id': 'p4cam-1', 'superseded_at': null}
    ];
    expect((await repo.getById('live'))?.id, 'live');
  });
}
