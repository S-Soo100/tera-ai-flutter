import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_alert_prefs_repository.dart';
import 'package:vivanaut/features/home/presentation/env_alert_prefs_providers.dart';

/// 가짜 PostgREST — GET은 [rows]를 돌려주고, POST(upsert)는 기록한 뒤
/// [failWrites]면 500, 아니면 201(본문 없음 = return=minimal).
class _FakeServer {
  _FakeServer({Map<String, List<Map<String, Object?>>>? rowsByUser})
      : rowsByUser = rowsByUser ?? {};

  final Map<String, List<Map<String, Object?>>> rowsByUser;
  bool failWrites = false;

  /// 본문에 이 열이 있는 쓰기만 실패시킨다.
  String? failColumn;
  Completer<void>? holdWrites;
  final List<http.Request> requests = [];

  List<http.Request> get writes =>
      requests.where((r) => r.method == 'POST').toList();

  SupabaseClient client() => SupabaseClient('https://example.test', 'anon',
          httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          final uid = (request.url.queryParameters['user_id'] ?? '')
              .replaceFirst('eq.', '');
          return http.Response(jsonEncode(rowsByUser[uid] ?? const []), 200,
              request: request, headers: {'content-type': 'application/json'});
        }
        if (holdWrites != null) await holdWrites!.future;
        final body = jsonDecode(request.body);
        final failThis = failWrites ||
            (failColumn != null && body is Map && body.containsKey(failColumn));
        if (failThis) {
          return http.Response('{"message":"boom","code":"XX000"}', 500,
              request: request, headers: {'content-type': 'application/json'});
        }
        return http.Response('', 201, request: request);
      }));
}

User _user(String id) => User(
    id: id,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01');

void main() {
  group('EnvAlertPrefsRepository', () {
    test('행 없으면 둘 다 true', () async {
      final server = _FakeServer();
      final client = server.client();
      addTearDown(client.dispose);
      final prefs = await EnvAlertPrefsRepository(client, userId: 'u1').load();
      expect(prefs, const EnvAlertPrefs(temp: true, humid: true));
      final get = server.requests.single;
      expect(get.url.path, '/rest/v1/notification_preferences');
      expect(get.url.queryParameters['user_id'], 'eq.u1');
    });

    test('저장된 행을 읽는다', () async {
      final server = _FakeServer(rowsByUser: {
        'u1': [
          {'env_temp': true, 'env_humid': false}
        ]
      });
      final client = server.client();
      addTearDown(client.dispose);
      expect(await EnvAlertPrefsRepository(client, userId: 'u1').load(),
          const EnvAlertPrefs(temp: true, humid: false));
    });

    test('setHumid(false) → upsert 본문에 env_humid만', () async {
      final server = _FakeServer();
      final client = server.client();
      addTearDown(client.dispose);
      await EnvAlertPrefsRepository(client,
          userId: 'u1',
          now: () => DateTime.utc(2026, 11, 2, 5)).setHumid(false);
      final w = server.writes.single;
      expect(w.url.path, '/rest/v1/notification_preferences');
      expect(w.url.queryParameters['on_conflict'], 'user_id');
      expect(w.url.queryParameters.containsKey('select'), isFalse,
          reason: '.select() 없이 — return=minimal');
      expect(w.headers['Prefer'] ?? w.headers['prefer'],
          contains('resolution=merge-duplicates'));
      expect(jsonDecode(w.body), {
        'user_id': 'u1',
        'env_humid': false,
        'updated_at': '2026-11-02T05:00:00.000Z',
      });
    });

    test('setTemp(true) → upsert 본문에 env_temp만', () async {
      final server = _FakeServer();
      final client = server.client();
      addTearDown(client.dispose);
      await EnvAlertPrefsRepository(client, userId: 'u1').setTemp(true);
      final body = jsonDecode(server.writes.single.body) as Map;
      expect(body.keys.toSet(), {'user_id', 'env_temp', 'updated_at'});
      expect(body['env_temp'], isTrue);
    });
  });

  group('envAlertPrefsProvider', () {
    ProviderContainer containerFor(_FakeServer server,
        {StateProvider<String?>? userId}) {
      final uid = userId ?? StateProvider<String?>((ref) => 'u1');
      final client = server.client();
      addTearDown(client.dispose);
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) {
          final id = ref.watch(uid);
          return id == null ? null : _user(id);
        }),
        envAlertPrefsRepositoryProvider.overrideWith(
            (ref, id) => EnvAlertPrefsRepository(client, userId: id)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('행 없으면 둘 다 true', () async {
      final c = containerFor(_FakeServer());
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      expect(await c.read(envAlertPrefsProvider.future),
          const EnvAlertPrefs(temp: true, humid: true));
    });

    test('저장 성공 시 바뀐 값 유지', () async {
      final server = _FakeServer();
      final c = containerFor(server);
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(envAlertPrefsProvider.future);
      await c.read(envAlertPrefsProvider.notifier).setHumid(false);
      expect(c.read(envAlertPrefsProvider).value,
          const EnvAlertPrefs(temp: true, humid: false));
    });

    test('낙관적으로 먼저 바꾼다', () async {
      final server = _FakeServer()..holdWrites = Completer<void>();
      final c = containerFor(server);
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(envAlertPrefsProvider.future);
      final pending = c.read(envAlertPrefsProvider.notifier).setTemp(false);
      expect(c.read(envAlertPrefsProvider).value?.temp, isFalse);
      server.holdWrites!.complete();
      await pending;
      expect(c.read(envAlertPrefsProvider).value?.temp, isFalse);
    });

    test('저장 실패 시 state 원복 + 예외 다시 던짐', () async {
      final server = _FakeServer()..failWrites = true;
      final c = containerFor(server);
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(envAlertPrefsProvider.future);
      await expectLater(c.read(envAlertPrefsProvider.notifier).setHumid(false),
          throwsA(isA<PostgrestException>()));
      expect(c.read(envAlertPrefsProvider).value,
          const EnvAlertPrefs(temp: true, humid: true));
    });

    test('한쪽 실패는 그쪽만 원복 — 동시에 바꾼 다른 쪽은 유지', () async {
      final server = _FakeServer()
        ..holdWrites = Completer<void>()
        ..failColumn = 'env_temp';
      final c = containerFor(server);
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(envAlertPrefsProvider.future);
      final notifier = c.read(envAlertPrefsProvider.notifier);
      final humid = notifier.setHumid(false);
      final temp = notifier.setTemp(false);
      expect(c.read(envAlertPrefsProvider).value,
          const EnvAlertPrefs(temp: false, humid: false));
      server.holdWrites!.complete();
      await humid;
      await expectLater(temp, throwsA(isA<PostgrestException>()));
      expect(c.read(envAlertPrefsProvider).value,
          const EnvAlertPrefs(temp: true, humid: false));
    });

    test('계정이 바뀌면 그 계정 행을 다시 읽는다', () async {
      final uid = StateProvider<String?>((ref) => 'a');
      final server = _FakeServer(rowsByUser: {
        'a': [
          {'env_temp': false, 'env_humid': false}
        ],
      });
      final c = containerFor(server, userId: uid);
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      expect(await c.read(envAlertPrefsProvider.future),
          const EnvAlertPrefs(temp: false, humid: false));
      c.read(uid.notifier).state = 'b';
      expect(await c.read(envAlertPrefsProvider.future),
          const EnvAlertPrefs(temp: true, humid: true));
    });

    test('실패 응답이 계정 전환 뒤에 와도 새 계정 값을 건드리지 않는다', () async {
      final uid = StateProvider<String?>((ref) => 'a');
      final server = _FakeServer(rowsByUser: {
        'b': [
          {'env_temp': false, 'env_humid': true}
        ],
      })
        ..holdWrites = Completer<void>()
        ..failWrites = true;
      final c = containerFor(server, userId: uid);
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(envAlertPrefsProvider.future);
      final pending = c.read(envAlertPrefsProvider.notifier).setTemp(false);
      c.read(uid.notifier).state = 'b';
      expect(await c.read(envAlertPrefsProvider.future),
          const EnvAlertPrefs(temp: false, humid: true));
      server.holdWrites!.complete();
      await expectLater(pending, throwsA(isA<PostgrestException>()));
      expect(c.read(envAlertPrefsProvider).value,
          const EnvAlertPrefs(temp: false, humid: true));
    });

    test('로그아웃 상태에서는 쓰지 않고 StateError', () async {
      final server = _FakeServer();
      final c =
          containerFor(server, userId: StateProvider<String?>((ref) => null));
      final sub = c.listen(envAlertPrefsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(envAlertPrefsProvider.future);
      await expectLater(c.read(envAlertPrefsProvider.notifier).setTemp(false),
          throwsStateError);
      expect(server.writes, isEmpty);
    });
  });
}
