import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 인증 오류를 사용자가 할 일이 보이는 한글 문구로 바꾼다.
///
/// 서버 영문 메시지를 그대로 스낵바에 띄우지 않는다(UX-07). 분류는 `code`
/// 우선, 구 서버 응답은 메시지 문자열로 보조 판정한다.
String authErrorText(Object error) {
  if (error is AuthRetryableFetchException) return 'auth_error_network'.tr();
  if (error is! AuthException) return 'auth_error_generic'.tr();
  final code = error.code ?? '';
  final msg = error.message.toLowerCase();
  if (error is AuthWeakPasswordException ||
      code == 'weak_password' ||
      msg.contains('password should')) {
    return 'auth_error_weak_password'.tr();
  }
  if (code == 'same_password' || msg.contains('different from the old')) {
    return 'auth_error_same_password'.tr();
  }
  if (code == 'otp_expired' ||
      code == 'invalid_otp' ||
      msg.contains('token has expired') ||
      msg.contains('otp')) {
    return 'auth_error_otp_invalid'.tr();
  }
  if (code.contains('rate_limit') ||
      error.statusCode == '429' ||
      msg.contains('rate limit') ||
      msg.contains('security purposes')) {
    return 'auth_error_rate_limit'.tr();
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      msg.contains('already registered')) {
    return 'auth_error_already_registered'.tr();
  }
  if (code == 'email_address_invalid' || msg.contains('invalid format')) {
    return 'auth_email_invalid'.tr();
  }
  return 'auth_error_generic'.tr();
}
