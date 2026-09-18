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
}
