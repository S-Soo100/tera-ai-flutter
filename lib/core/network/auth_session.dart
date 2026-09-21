import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 서버에 보낼 access token의 단일 통로이자, 401을 만났을 때의 복구 규칙.
///
/// **왜 필요한가** (2026-09-21 "자동로그인이 자꾸 풀린다"):
/// 이전에는 세 군데(terra REST·클립·WebRTC)가 각자
/// `currentSession?.accessToken`을 **갱신 없이** 읽어 보내고, 401이 오면 곧장
/// `signOut()`을 불렀다. `currentSession`은 만료된 세션도 그대로 돌려주므로
/// 앱을 한참 띄워 두었다 돌아오면 ① 만료 토큰을 보내고 ② 401을 받고
/// ③ **멀쩡한 refresh token을 버린 채 로그아웃**했다. 사용자에겐 "자동
/// 로그인이 풀린" 것으로 보인다.
///
/// 그래서 규칙을 하나로 모은다:
/// - 보내기 전에 만료가 임박했으면 **먼저 갱신**한다.
/// - 401을 받으면 **갱신 후 한 번 더 시도**한다.
/// - 로그아웃은 **refresh 자체가 거부당했을 때만**(= 세션이 정말 끝났을 때).
///   네트워크 실패로는 로그아웃하지 않는다 — 비행기 모드가 로그아웃 사유일
///   수는 없다.
abstract interface class AuthSession {
  /// 지금 보낼 access token. 만료가 가까우면 갱신해서 돌려준다.
  /// 세션이 없으면 null.
  Future<String?> accessToken();

  /// 401을 받은 직후 호출한다.
  ///
  /// true = 세션을 되살렸으니 **한 번 더 보내 봐라**.
  /// false = 되살리지 못했다. 세션이 끝난 경우라면 이미 로그아웃까지 했다.
  Future<bool> recoverFromUnauthorized();
}

class SupabaseAuthSession implements AuthSession {
  SupabaseAuthSession(this._auth, {this.skew = const Duration(minutes: 1)});

  final GoTrueClient _auth;

  /// 이만큼 안에 만료되면 미리 갱신한다. 요청이 날아가는 동안 만료되는
  /// 경계(= 보낼 땐 유효했는데 서버가 받을 땐 만료)를 없앤다.
  final Duration skew;

  /// 동시 갱신 합치기 — 화면 여럿이 한꺼번에 401을 받아도 refresh는 한 번만
  /// 나간다. refresh token은 한 번 쓰면 회전하므로 동시 호출은 서로를 무효화할
  /// 수 있다.
  Future<Session?>? _inFlight;

  @override
  Future<String?> accessToken() async {
    final session = _auth.currentSession;
    if (session == null) return null;
    if (!_expiringSoon(session)) return session.accessToken;
    // 갱신에 실패해도 있는 토큰은 보낸다 — 서버가 아직 받아 줄 수도 있고,
    // 진짜 만료라면 401 경로에서 다시 판정한다.
    return (await _refresh())?.accessToken ?? session.accessToken;
  }

  @override
  Future<bool> recoverFromUnauthorized() async {
    if (_auth.currentSession == null) return false;
    try {
      return (await _refresh(rethrowAuthError: true)) != null;
    } on AuthException {
      // refresh token까지 거부당했다 = 세션이 정말 끝났다.
      await _auth.signOut();
      return false;
    }
  }

  bool _expiringSoon(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    final deadline =
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
    return deadline.isBefore(DateTime.now().toUtc().add(skew));
  }

  Future<Session?> _refresh({bool rethrowAuthError = false}) {
    final pending = _inFlight ??= _auth
        .refreshSession()
        .then((response) => response.session)
        .whenComplete(() => _inFlight = null);
    return pending.catchError((Object error) {
      if (rethrowAuthError && error is AuthException) throw error;
      return null;
    });
  }
}

final authSessionProvider = Provider<AuthSession>(
    (ref) => SupabaseAuthSession(Supabase.instance.client.auth));
