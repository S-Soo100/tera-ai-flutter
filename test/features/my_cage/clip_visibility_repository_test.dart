import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';

void main() {
  for (final code in ['PGRST205', '42P01']) {
    test('$code missing table allows read but never pretends hide succeeded',
        () async {
      final requests = <http.Request>[];
      final client = SupabaseClient('https://example.test', 'anon',
          httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode({'message': 'table missing', 'code': code}), 404,
            request: request, headers: {'content-type': 'application/json'});
      }));
      addTearDown(client.dispose);
      final repository = SupabaseClipVisibilityRepository(
          supabase: client, accountIdProvider: () => 'a');
      expect(await repository.hiddenClipIds('a'), isEmpty);
      await expectLater(
          repository.hide('a', 'clip'), throwsA(isA<PostgrestException>()));
      expect(requests.map((r) => r.method), ['GET', 'POST']);
      expect(requests.every((r) => r.url.path.endsWith('/user_hidden_clips')),
          true);
    });
  }
  test('account mismatch sends no request; RLS errors do not become empty list',
      () async {
    var requests = 0;
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests++;
      return http.Response('{"message":"denied","code":"42501"}', 403,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repository = SupabaseClipVisibilityRepository(
        supabase: client, accountIdProvider: () => 'a');
    await expectLater(repository.hide('b', 'clip'), throwsStateError);
    expect(requests, 0);
    await expectLater(
        repository.hiddenClipIds('a'), throwsA(isA<PostgrestException>()));
  });
  test(
      'only owner-scoped hide insert is sent and more than 1000 rows page by UUID',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'anon',
        httpClient: MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response('', 201, request: request);
      }
      final after = request.url.queryParameters['clip_id'];
      final rows = after == null
          ? [
              for (var i = 0; i < 1000; i++)
                {'clip_id': 'id${i.toString().padLeft(4, '0')}'}
            ]
          : [
              {'clip_id': 'last'}
            ];
      return http.Response(jsonEncode(rows), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repository = SupabaseClipVisibilityRepository(
        supabase: client, accountIdProvider: () => 'a');
    expect((await repository.hiddenClipIds('a')).length, 1001);
    expect(requests[1].url.queryParameters['clip_id'], 'gt.id0999');
    await repository.hide('a', 'clip');
    expect(jsonDecode(requests.last.body), {'user_id': 'a', 'clip_id': 'clip'});
    expect(requests.last.headers['prefer'],
        contains('resolution=ignore-duplicates'));
    expect(requests.any((r) => r.method == 'DELETE'), false);
    expect(
        requests.every((r) => r.url.path.endsWith('/user_hidden_clips')), true);
  });
}
