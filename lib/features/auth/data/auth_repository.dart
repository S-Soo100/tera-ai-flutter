import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
  }) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  Future<ResendResponse> resendSignupOTP({required String email}) async {
    return await _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 비밀번호 변경(Figma MyAcc_pwchange 1134:7865) — 현재 비밀번호는 재로그인으로
  /// 검증한다(Supabase에 "현재 비밀번호 확인" API가 없다). 틀리면
  /// [AuthException]이 그대로 올라온다.
  Future<void> changePassword(
      {required String current, required String next}) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw StateError('로그인이 필요합니다');
    await _client.auth.signInWithPassword(email: email, password: current);
    await _client.auth.updateUser(UserAttributes(password: next));
  }

  /// 회원 탈퇴(Figma MyAcc_withdraw 1142:8361). 클라이언트는 `auth.users`를
  /// 지울 수 없어 Edge Function `delete-account`(service role) 에 위임한다 —
  /// 2026-09-16 현재 **미배포**(이관훈님 합의 필요, 계획 C6). 없으면
  /// [FunctionException]이 올라오고 화면이 "아직 준비되지 않았다"고 말한다.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut();
  }
}
