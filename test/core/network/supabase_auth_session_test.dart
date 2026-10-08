import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/network/auth_session.dart';

/// refresh 결과만 정해 두는 가짜 GoTrueClient.
class _Auth implements GoTrueClient {
  _Auth(this._refresh);

  final Future<AuthResponse> Function() _refresh;
  Session? session = _session('old');
  int signOuts = 0;

  @override
  Session? get currentSession => session;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) => _refresh();

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOuts++;
    session = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session(String token) => Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-09T00:00:00Z',
      ),
    );

/// 2026-10-09 — 401 직후 갱신이 네트워크 문제로 실패하면 멀쩡한 세션을 버리던 결함.
/// `AuthRetryableFetchException`(망 끊김·타임아웃·5xx)도 `AuthException`이다.
void main() {
  test('갱신이 네트워크 오류로 실패하면 로그아웃하지 않는다', () async {
    final auth = _Auth(() async => throw AuthRetryableFetchException(
        message: 'SocketException: Failed host lookup'));
    final session = SupabaseAuthSession(auth);

    expect(await session.recoverFromUnauthorized(), isFalse);
    expect(auth.signOuts, 0, reason: '비행기 모드가 로그아웃 사유일 수는 없다');
    expect(auth.currentSession, isNotNull);
  });

  test('서버 5xx로 갱신이 실패해도 로그아웃하지 않는다', () async {
    final auth = _Auth(() async =>
        throw AuthRetryableFetchException(message: 'bad gateway', statusCode: '502'));

    expect(await SupabaseAuthSession(auth).recoverFromUnauthorized(), isFalse);
    expect(auth.signOuts, 0);
  });

  test('서버가 refresh token을 거부하면 로그아웃한다', () async {
    final auth = _Auth(() async => throw AuthApiException(
        'Invalid Refresh Token: Refresh Token Not Found',
        statusCode: '400',
        code: 'refresh_token_not_found'));

    expect(await SupabaseAuthSession(auth).recoverFromUnauthorized(), isFalse);
    expect(auth.signOuts, 1);
  });

  test('갱신에 성공하면 다시 보내라고 알린다', () async {
    final auth = _Auth(() async => AuthResponse(session: _session('new')));

    expect(await SupabaseAuthSession(auth).recoverFromUnauthorized(), isTrue);
    expect(auth.signOuts, 0);
  });

  test('세션이 없으면 갱신하지 않는다', () async {
    var refreshed = false;
    final auth = _Auth(() async {
      refreshed = true;
      return AuthResponse();
    })
      ..session = null;

    expect(await SupabaseAuthSession(auth).recoverFromUnauthorized(), isFalse);
    expect(refreshed, isFalse);
  });
}
