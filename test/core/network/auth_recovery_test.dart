import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';

/// 401을 만났을 때의 복구를 기록으로 본다.
class _Session implements AuthSession {
  _Session({this.recovers = false});

  bool recovers;
  String? token = 'stale';
  int recoveries = 0;
  final List<String?> handedOut = [];

  @override
  Future<String?> accessToken() async {
    handedOut.add(token);
    return token;
  }

  @override
  Future<bool> recoverFromUnauthorized() async {
    recoveries++;
    if (!recovers) return false;
    token = 'fresh';
    return true;
  }
}

/// 요청마다 미리 정해 둔 응답을 돌려준다.
class _Client extends http.BaseClient {
  _Client(this._responses);
  final List<http.Response> _responses;
  final List<String?> sentTokens = [];
  var _index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sentTokens.add(request.headers['Authorization']);
    final resp = _responses[_index.clamp(0, _responses.length - 1)];
    _index++;
    return http.StreamedResponse(Stream.value(resp.bodyBytes), resp.statusCode);
  }

  int get calls => _index;
}

/// 2026-09-21 "자동로그인이 자꾸 풀린다" — 401 한 번에 로그아웃하던 규칙의 교체.
void main() {
  TerraRestClient clientWith(_Session session, _Client http_) =>
      TerraRestClient(
          baseUrl: 'https://terra.test', session: session, httpClient: http_);

  test('401이면 세션을 되살려 한 번 더 보낸다', () async {
    final session = _Session(recovers: true);
    final transport = _Client([
      http.Response('{"detail":"expired"}', 401),
      http.Response('{"ok":true}', 200),
    ]);

    final body = await clientWith(session, transport).get('/schedules');

    expect(session.recoveries, 1);
    expect(transport.calls, 2, reason: '되살렸으면 다시 보낸다');
    expect(body, {'ok': true});
    expect(transport.sentTokens.last, 'Bearer fresh',
        reason: '재시도는 새 토큰으로 나간다');
  });

  test('되살리지 못하면 401을 그대로 올린다 — 재시도하지 않는다', () async {
    final session = _Session();
    final transport = _Client([http.Response('{"detail":"nope"}', 401)]);

    await expectLater(
        clientWith(session, transport).get('/schedules'),
        throwsA(isA<TerraRestException>()
            .having((e) => e.statusCode, 'statusCode', 401)));
    expect(session.recoveries, 1);
    expect(transport.calls, 1);
  });

  test('되살린 뒤에도 401이면 그 401을 올린다 — 토큰 문제가 아니다', () async {
    // 예: 남의 기기를 조회했다. 여기서 로그아웃시키면 멀쩡한 세션이 날아간다.
    final session = _Session(recovers: true);
    final transport = _Client([
      http.Response('{"detail":"forbidden"}', 401),
      http.Response('{"detail":"forbidden"}', 401),
    ]);

    await expectLater(
        clientWith(session, transport).get('/devices/x/schedules'),
        throwsA(isA<TerraRestException>()
            .having((e) => e.statusCode, 'statusCode', 401)));
    expect(session.recoveries, 1, reason: '복구는 한 번만 시도한다');
    expect(transport.calls, 2);
  });

  test('200이면 복구를 건드리지 않는다', () async {
    final session = _Session();
    final transport = _Client([http.Response('[]', 200)]);

    expect(await clientWith(session, transport).get('/schedules'), isEmpty);
    expect(session.recoveries, 0);
    expect(transport.calls, 1);
  });
}
