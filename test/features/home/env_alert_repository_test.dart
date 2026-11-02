// v4 실시간 이탈 저장소(계획 Task 6) — 조회·실시간 반영·재합류 재조회.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/home/data/env_alert_repository.dart';
import 'package:vivanaut/features/home/domain/env_alert.dart';

Map<String, dynamic> _row({
  required String id,
  String kind = 'env_temp_low',
  String level = 'caution',
  String message = '[저온 주의] 적정 온도보다 -0.5℃',
  String triggeredAt = '2026-11-02T05:00:00+00:00',
  String? resolvedAt,
  String rule = 'v4',
  String deviceId = 'd1',
}) =>
    {
      'id': id,
      'device_id': deviceId,
      'kind': kind,
      'severity': 'warning',
      'message': message,
      'context': {'rule': rule, 'level': level},
      'triggered_at': triggeredAt,
      'resolved_at': resolvedAt,
    };

/// 가짜 PostgREST — GET은 [rows]를 돌려준다. [hold]가 있으면 그때까지 기다린다.
class _FakeServer {
  List<Map<String, dynamic>> rows = [];
  bool fail = false;
  Completer<void>? hold;
  final List<http.Request> requests = [];

  SupabaseClient client() => SupabaseClient('https://example.test', 'anon',
          httpClient: MockClient((request) async {
        requests.add(request);
        final snapshot = jsonEncode(rows);
        final failNow = fail;
        if (hold != null) await hold!.future;
        if (failNow) {
          return http.Response('{"message":"boom","code":"XX000"}', 500,
              request: request, headers: {'content-type': 'application/json'});
        }
        return http.Response(snapshot, 200,
            request: request, headers: {'content-type': 'application/json'});
      }));
}

/// 가짜 구독 — 실시간 행과 재합류를 손으로 넣는다.
class _FakeChannel {
  void Function(Map<String, dynamic>)? onRow;
  VoidCallback? onRejoined;
  String? deviceId;
  var closed = false;

  VoidCallback subscribe(String id,
      {required void Function(Map<String, dynamic>) onRow,
      required VoidCallback onRejoined}) {
    deviceId = id;
    this.onRow = onRow;
    this.onRejoined = onRejoined;
    return () => closed = true;
  }
}

void main() {
  late _FakeServer server;
  late SupabaseClient client;
  late _FakeChannel channel;
  late List<List<String>> seen;
  late StreamSubscription<List<EnvAlert>> sub;

  setUp(() {
    server = _FakeServer();
    client = server.client();
    channel = _FakeChannel();
    seen = [];
  });
  tearDown(() async {
    await sub.cancel();
    await client.dispose();
  });

  Future<void> listen() async {
    sub = EnvAlertRepository(client)
        .watchOpen('d1', subscribe: channel.subscribe)
        .listen((list) => seen.add([for (final a in list) a.id]));
    await pumpEventQueue();
  }

  test('처음 조회 — 기기·열린 행·env_ 접두 조건, v4만 남긴다', () async {
    server.rows = [
      _row(id: 'a'),
      _row(id: 'legacy', kind: 'env_humid_low', rule: 'legacy'),
    ];
    await listen();
    expect(seen, [
      ['a']
    ]);
    final q = server.requests.single.url;
    expect(q.path, '/rest/v1/alerts');
    expect(q.queryParameters['device_id'], 'eq.d1');
    expect(q.queryParameters['resolved_at'], 'is.null');
    expect(q.queryParameters['kind'], r'like.env\_%');
    expect(channel.deviceId, 'd1');
  });

  test('실시간 INSERT는 더하고, 종료 UPDATE는 뺀다', () async {
    await listen();
    expect(seen, [<String>[]]);
    channel.onRow!(_row(id: 'h1', kind: 'env_humid_low'));
    await pumpEventQueue();
    expect(seen.last, ['h1']);
    channel.onRow!(_row(
        id: 'h1', kind: 'env_humid_low', resolvedAt: '2026-11-02T06:00:00Z'));
    await pumpEventQueue();
    expect(seen.last, isEmpty);
  });

  test('주의→경고 — 기존 행 종료 + 새 행이면 경고 한 줄만', () async {
    server.rows = [_row(id: 'c')];
    await listen();
    channel.onRow!(_row(
        id: 'd',
        level: 'danger',
        message: '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요'));
    await pumpEventQueue();
    expect(seen.last, ['d']);
    channel.onRow!(_row(id: 'c', resolvedAt: '2026-11-02T05:00:00Z'));
    await pumpEventQueue();
    expect(seen.last, ['d']);
    // 같은 목록은 다시 내보내지 않는다.
    expect(seen.where((s) => s.length == 1 && s.first == 'd'), hasLength(1));
  });

  test('v4가 아니거나 다른 기기 행은 실시간으로 와도 무시', () async {
    await listen();
    channel.onRow!(_row(id: 'x', rule: 'legacy'));
    channel.onRow!(_row(id: 'y', deviceId: 'd2'));
    channel.onRow!({..._row(id: 'z'), 'kind': 'temp_high'});
    await pumpEventQueue();
    expect(seen, [<String>[]]);
  });

  test('rejoin_refetches_and_drops_resolved', () async {
    server.rows = [_row(id: 'a'), _row(id: 'b', kind: 'env_humid_high')];
    await listen();
    expect(seen.last, ['a', 'b']);
    // 끊긴 사이 a가 종료됐다 — 종료 UPDATE는 놓쳤다.
    server.rows = [_row(id: 'b', kind: 'env_humid_high')];
    channel.onRejoined!();
    await pumpEventQueue();
    expect(seen.last, ['b']);
    expect(server.requests, hasLength(2));
  });

  test('조회 중에 온 실시간 행은 조회 결과 위에 다시 얹는다', () async {
    server.rows = [_row(id: 'a')];
    server.hold = Completer<void>();
    await listen();
    expect(seen, isEmpty); // 처음 조회 전에는 내보내지 않는다.
    channel.onRow!(_row(id: 'h', kind: 'env_humid_low'));
    channel.onRow!(_row(id: 'a', resolvedAt: '2026-11-02T05:30:00Z'));
    server.hold!.complete();
    await pumpEventQueue();
    expect(seen, [
      ['h']
    ]);
  });

  test('처음 조회 실패는 오류, 재합류 조회가 성공하면 목록', () async {
    server.fail = true;
    final errors = <Object>[];
    sub = EnvAlertRepository(client)
        .watchOpen('d1', subscribe: channel.subscribe)
        .listen((list) => seen.add([for (final a in list) a.id]),
            onError: errors.add);
    await pumpEventQueue();
    expect(errors, hasLength(1));
    server
      ..fail = false
      ..rows = [_row(id: 'a')];
    channel.onRejoined!();
    await pumpEventQueue();
    expect(seen, [
      ['a']
    ]);
  });

  test('처음 조회 실패 → 재합류 없이도 잠시 뒤 다시 조회한다', () async {
    server.fail = true;
    final errors = <Object>[];
    sub = EnvAlertRepository(client)
        .watchOpen('d1',
            subscribe: channel.subscribe,
            retryDelay: (_) => const Duration(milliseconds: 10))
        .listen((list) => seen.add([for (final a in list) a.id]),
            onError: errors.add);
    await pumpEventQueue();
    expect(errors, hasLength(1));
    server
      ..fail = false
      ..rows = [_row(id: 'a')];
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await pumpEventQueue();
    expect(seen, [
      ['a']
    ]);
    expect(server.requests, hasLength(2));
  });

  test('못 불러온 상태에서 실시간 행이 오면 바로 다시 조회한다', () async {
    server.fail = true;
    sub = EnvAlertRepository(client)
        .watchOpen('d1',
            subscribe: channel.subscribe,
            retryDelay: (_) => const Duration(hours: 1))
        .listen((list) => seen.add([for (final a in list) a.id]),
            onError: (_) {});
    await pumpEventQueue();
    server
      ..fail = false
      ..rows = [_row(id: 'a')];
    channel.onRow!(_row(id: 'h', kind: 'env_humid_low'));
    await pumpEventQueue();
    expect(seen.last, ['a', 'h']);
  });

  test('구독을 끊으면 채널을 닫는다', () async {
    await listen();
    expect(channel.closed, isFalse);
    await sub.cancel();
    expect(channel.closed, isTrue);
  });
}
