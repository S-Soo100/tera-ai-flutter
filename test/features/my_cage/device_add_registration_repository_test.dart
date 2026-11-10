import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/my_cage/data/device_add_registration_repository.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

void main() {
  test('PAIR_OK exact kind-specific ID and owner_id resolve UUID by GET only',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode([
            {'id': 'uuid'}
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo = DeviceAddRegistrationRepository(client,
        accountIdProvider: () => 'owner');
    expect(
        await repo.confirm('owner', PairTargetKind.camera, 'arbitrary-prefix'),
        'uuid');
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/rest/v1/cameras');
    expect(requests.single.url.queryParameters, {
      'select': 'id',
      'owner_id': 'eq.owner',
      'camera_id': 'eq.arbitrary-prefix',
      'limit': '2'
    });
    await expectLater(repo.confirm('other', PairTargetKind.device, 'arbitrary'),
        throwsStateError);
    expect(requests.length, 1);
  });
  test('account switch while confirming rejects late server row', () async {
    var account = 'a';
    final pending = Completer<http.Response>();
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      final response = await pending.future;
      return http.Response(response.body, response.statusCode,
          request: request, headers: response.headers);
    }));
    addTearDown(client.dispose);
    final repo = DeviceAddRegistrationRepository(client,
        accountIdProvider: () => account);
    final request = repo.confirm('a', PairTargetKind.device, 'mqtt');
    account = 'b';
    pending.complete(http.Response('[{"id":"uuid"}]', 200,
        headers: {'content-type': 'application/json'}));
    await expectLater(request, throwsStateError);
  });
  test('ambiguous hardware matches never pick arbitrary owner row', () async {
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async => http.Response(
            '[{"id":"one"},{"id":"two"}]', 200,
            request: request, headers: {'content-type': 'application/json'})));
    addTearDown(client.dispose);
    final repo = DeviceAddRegistrationRepository(client,
        accountIdProvider: () => 'owner');
    expect(await repo.confirm('owner', PairTargetKind.device, 'mqtt'), isNull);
  });

  test('owned는 이 계정 행만 보고, 없으면 null', () async {
    final requests = <http.Request>[];
    var body =
        '[{"id":"row","last_seen_at":"2026-09-21T07:05:41Z","hw_id":"2884856F2548","is_online":true}]';
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(body, 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo = DeviceAddRegistrationRepository(client,
        accountIdProvider: () => 'owner');
    final found = await repo.owned('owner', PairTargetKind.camera, 'row');
    expect(found?.lastSeen, DateTime.utc(2026, 9, 21, 7, 5, 41));
    expect(found?.hardwareId, '2884856F2548');
    expect(found?.isOnline, isTrue);
    expect(requests.single.url.path, endsWith('/cameras'));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.queryParameters['owner_id'], 'eq.owner');
    expect(requests.single.url.queryParameters['id'], 'eq.row');
    body = '[]';
    expect(await repo.owned('owner', PairTargetKind.device, 'row'), isNull);
    expect(requests.last.url.path, endsWith('/devices'));
    body =
        '[{"id":"row","last_seen_at":null,"unlinked_at":"2026-09-20T00:00:00Z"}]';
    expect(await repo.owned('owner', PairTargetKind.camera, 'row'), isNull,
        reason: '해제한 기기는 새로 등록해야 목록에 다시 보인다');
  });

  // 2026-11-10 서버 계약: superseded_at은 cameras에만 있다. devices에 그 컬럼을
  // 고르면 PostgREST가 400을 내 사육장 추가·Wi-Fi 바꾸기 판정이 깨진다.
  test('owned는 카메라만 superseded_at을 보고, 사육장 조회엔 넣지 않는다', () async {
    final requests = <http.Request>[];
    var body =
        '[{"id":"row","last_seen_at":null,"superseded_at":"2026-11-10T03:40:00Z"}]';
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(body, 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo = DeviceAddRegistrationRepository(client,
        accountIdProvider: () => 'owner');
    expect(await repo.owned('owner', PairTargetKind.camera, 'row'), isNull,
        reason: '다른 계정으로 넘어간 카메라는 새로 등록해야 한다');
    expect(requests.last.url.queryParameters['select'],
        contains('superseded_at'));
    body = '[{"id":"row","last_seen_at":null}]';
    expect(await repo.owned('owner', PairTargetKind.device, 'row'), isNotNull);
    expect(requests.last.url.path, endsWith('/devices'));
    expect(requests.last.url.queryParameters['select'],
        isNot(contains('superseded_at')));
  });
}
