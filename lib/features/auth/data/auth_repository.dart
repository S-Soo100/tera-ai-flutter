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

  /// 비밀번호 재설정 인증번호 요청(UX-01, 2026-10-01). 메일 링크가 아니라
  /// 가입 인증과 같은 **6자리 코드** 방식 — 앱에 딥링크 설정이 없어서다.
  /// ⚠️ Supabase 대시보드 "Reset Password" 메일 양식에 `{{ .Token }}`이 있어야
  /// 코드가 메일에 찍힌다(`docs/handoffs/2026-10-01-password-reset-otp-template.md`).
  /// 가입되지 않은 이메일도 서버는 성공으로 답한다(계정 존재 노출 방지).
  Future<void> sendPasswordResetCode({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// 재설정 코드 확인. 성공하면 복구 세션이 생긴다(= 로그인 상태) —
  /// 이어서 [updatePassword]로 새 비밀번호를 저장한다.
  Future<void> verifyPasswordResetCode({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  /// 복구 세션에서 새 비밀번호 저장. 현재 비밀번호 확인이 없는 경로라
  /// 재설정 화면에서만 쓴다(로그인 후 변경은 [changePassword]).
  Future<void> updatePassword(String next) async {
    await _client.auth.updateUser(UserAttributes(password: next));
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
    try {
      await _client.auth.signInWithPassword(email: email, password: current);
    } on AuthException catch (e) {
      // 재로그인 단계의 실패만 "현재 비밀번호 불일치"다 — updateUser의 400
      // (same_password 등)과 섞이지 않게 구분한다(리뷰 2026-09-16).
      throw WrongCurrentPasswordException(e);
    }
    await _client.auth.updateUser(UserAttributes(password: next));
  }

  /// 회원 탈퇴(Figma MyAcc_withdraw 1142:8361). 클라이언트는 `auth.users`를
  /// 지울 수 없어 Edge Function `delete-account`(service role) 에 위임한다 —
  /// 2026-09-16 현재 **미배포**(이관훈님 합의 필요, 계획 C6). 없으면
  /// [FunctionException]이 올라오고 화면이 "아직 준비되지 않았다"고 말한다.
  /// 삭제만 한다 — 이어지는 로그아웃은 호출자가 푸시 기기 정리 경로
  /// (`pushLifecycleController.logout`)로 수행한다.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
  }
}

/// [AuthRepository.changePassword]의 재로그인 단계 실패 — 현재 비밀번호 불일치.
class WrongCurrentPasswordException implements Exception {
  const WrongCurrentPasswordException(this.cause);
  final AuthException cause;
  @override
  String toString() => 'WrongCurrentPasswordException(${cause.message})';
}
