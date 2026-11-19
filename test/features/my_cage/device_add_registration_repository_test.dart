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
    expect(
        requests.last.url.queryParameters['select'], contains('superseded_at'));
    body = '[{"id":"row","last_seen_at":null}]';
    expect(await repo.owned('owner', PairTargetKind.device, 'row'), isNotNull);
    expect(requests.last.url.path, endsWith('/devices'));
    expect(requests.last.url.queryParameters['select'],
        isNot(contains('superseded_at')));
  });

  // 리뷰(2026-11-19): 보내기 직전 재확인·폴링은 그 행 하나만 읽는다.
  test('networkDevice는 그 종류 테이블에서 그 행 하나만 읽는다', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests.add(request);
      final body = request.url.path == '/rest/v1/cameras'
          ? [
              {
                'id': 'c1',
                'name': '카메라 4',
                'is_online': true,
                'clip_stats': {
                  'sys': {'rssi': -78, 'uptime_s': 30}
                },
              }
            ]
          : [];
      return http.Response(jsonEncode(body), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo =
        DeviceAddRegistrationRepository(client, accountIdProvider: () => 'a');
    final cam = await repo.networkDevice('a', PairTargetKind.camera, 'c1');
    expect(requests.single.url.path, '/rest/v1/cameras');
    expect(requests.single.url.queryParameters,
        containsPair('id', 'eq.c1'));
    expect(requests.single.url.queryParameters,
        containsPair('owner_id', 'eq.a'));
    expect(cam!.uptimeSeconds, 30);
    expect(cam.wifiRssi, -78);
    expect(await repo.networkDevice('a', PairTargetKind.device, 'gone'),
        isNull);
  });

  // 네트워크 관리(2026-11-19): 화면 열 때·다시 스캔 때만 읽는다. 전체 열을
  // 골라 서버에 wifi_ssid가 생기면 앱 수정 없이 읽고, superseded_at은 cameras에만
  // 있어 서버 필터로 걸지 않고 앱에서 거른다.
  test('networkDevices는 이 계정 행만 전체 열로 읽고 해제·대체 행을 거른다', () async {
    final requests = <http.Request>[];
    final bodies = {
      '/rest/v1/devices': [
        {
          'id': 'd1',
          'name': '사육장 1',
          'hw_id': '2884856F2548',
          'is_online': true,
          'last_seen_at': '2026-11-19T01:02:03Z',
          'sys_state': {'rssi': -70, 'uptime_s': 120},
          'wifi_ssid': 'iptime',
          'unlinked_at': null
        },
        {
          'id': 'd2',
          'name': '사육장 2',
          'is_online': true,
          'unlinked_at': '2026-11-01T00:00:00Z'
        },
        {
          'id': 'd3',
          'name': '사육장 3',
          'hw_id': '',
          'is_online': false,
          'last_seen_at': null,
          'sys_state': null,
          'wifi_ssid': ''
        },
      ],
      '/rest/v1/cameras': [
        {
          'id': 'c1',
          'name': '카메라 4',
          'hw_id': 'AABBCCDDEE10',
          'is_online': true,
          'last_seen_at': '2026-11-19T01:00:00Z',
          'clip_stats': {
            'sys': {'rssi': -78.0, 'uptime_s': 3600}
          },
          'unlinked_at': null,
          'superseded_at': null
        },
        {
          'id': 'c2',
          'name': '카메라 5',
          'is_online': true,
          'superseded_at': '2026-11-10T03:40:00Z'
        },
        {'id': 'c3', 'name': '카메라 6', 'is_online': null},
      ],
    };
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(bodies[request.url.path]), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo =
        DeviceAddRegistrationRepository(client, accountIdProvider: () => 'a');
    final rows = await repo.networkDevices('a');

    expect(requests.map((r) => r.url.path).toSet(),
        {'/rest/v1/devices', '/rest/v1/cameras'});
    for (final r in requests) {
      expect(r.method, 'GET');
      expect(r.url.queryParameters, {'select': '*', 'owner_id': 'eq.a'},
          reason: 'superseded_at·unlinked_at은 서버 필터로 걸지 않는다');
    }
    expect(rows.map((r) => r.id), unorderedEquals(['d1', 'd3', 'c1', 'c3']),
        reason: '해제(d2)·대체(c2) 행은 뺀다');

    final d1 = rows.firstWhere((r) => r.id == 'd1');
    expect(d1.kind, PairTargetKind.device);
    expect(d1.name, '사육장 1');
    expect(d1.hardwareId, '2884856F2548');
    expect(d1.isOnline, isTrue);
    expect(d1.lastSeen, DateTime.utc(2026, 11, 19, 1, 2, 3));
    expect(d1.wifiRssi, -70);
    expect(d1.uptimeSeconds, 120);
    expect(d1.wifiSsid, 'iptime');

    final d3 = rows.firstWhere((r) => r.id == 'd3');
    expect(d3.isOnline, isFalse);
    expect(d3.hardwareId, isNull);
    expect(d3.lastSeen, isNull);
    expect(d3.wifiRssi, isNull);
    expect(d3.uptimeSeconds, isNull);
    expect(d3.wifiSsid, isNull, reason: '빈 문자열은 모름');

    final c1 = rows.firstWhere((r) => r.id == 'c1');
    expect(c1.kind, PairTargetKind.camera);
    expect(c1.wifiRssi, -78, reason: '서버 숫자가 소수로 와도 정수');
    expect(c1.uptimeSeconds, 3600);
    expect(c1.wifiSsid, isNull, reason: '열이 없으면 모름');

    final c3 = rows.firstWhere((r) => r.id == 'c3');
    expect(c3.isOnline, isNull);
    expect(c3.wifiRssi, isNull);

    await expectLater(repo.networkDevices('b'), throwsStateError);
    expect(requests.length, 2, reason: '다른 계정이면 요청하지 않는다');
  });

  test('networkDevices 도중 계정이 바뀌면 늦은 응답을 버린다', () async {
    var account = 'a';
    final pending = Completer<void>();
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      await pending.future;
      return http.Response('[]', 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo = DeviceAddRegistrationRepository(client,
        accountIdProvider: () => account);
    final request = repo.networkDevices('a');
    account = 'b';
    pending.complete();
    await expectLater(request, throwsStateError);
  });
}
