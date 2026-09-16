import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../core/theme/viva_colors.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/viva_check_row.dart';
import '../../../shared/widgets/viva_text_field.dart';
import '../data/auth_repository.dart';
import '../data/login_prefs_repository.dart';

/// 로그인 — Figma `Login` 1133:5712·1134:6114·1134:6259·1134:6472·1134:6617.
///
/// 393 프레임 기준: 로고 200×48.6 y98(안전영역 62 + 36) → 32 → 아이디 → 24 →
/// 비밀번호 → 12 → 체크 행(자동 로그인 · 오른쪽 비밀번호 규칙 오류) →
/// 플로팅 CTA 369×56 y696(하단 100), 키보드가 열리면 키보드 위 12.
/// CTA는 두 칸이 모두 채워졌을 때만 켜진다(비어 있으면 `#E3E3E3`).
///
/// 검증(계획 B5): 아이디는 이메일 형식, 비밀번호는 6자 이상만 막는다 —
/// 기존 계정의 비밀번호가 "영문+숫자+특수문자 6~12자" 규칙을 만족한다는 보장이
/// 없어 로그인에서 그 규칙을 강제하면 잠긴다(규칙은 가입 화면 몫). 규칙 문구는
/// 힌트와 짧은 비밀번호 오류에만 쓴다. 서버 인증 실패도 같은 자리에 적는다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _autoLogin = true;
  String? _emailError;
  String? _passwordError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(loginPrefsProvider);
    _emailController.text = prefs.lastEmail ?? '';
    _autoLogin = prefs.autoLogin;
    _emailController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {
        // 고치기 시작하면 그 칸의 오류는 지운다. 서버 오류도 재입력 시 사라진다.
        if (_emailError != null && _emailController.text.isNotEmpty) {
          _emailError = null;
        }
        if (_passwordError != null && _passwordController.text.isNotEmpty) {
          _passwordError = null;
        }
      });

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isLoading &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  bool _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError =
          _emailPattern.hasMatch(email) ? null : 'login_email_invalid'.tr();
      _passwordError =
          password.length >= 6 ? null : 'login_password_rule'.tr();
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _login() async {
    if (!_canSubmit || !_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: _passwordController.text,
          );
      await ref
          .read(loginPrefsProvider)
          .save(email: email, autoLogin: _autoLogin);
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _passwordError = _messageFor(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _passwordError = 'login_failed_generic'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Supabase 오류를 한글로. 자격 증명 오류(400)만 구분하고 나머지는 일반 문구.
  static String _messageFor(AuthException e) {
    final code = e.statusCode;
    final msg = e.message.toLowerCase();
    if (code == '400' || msg.contains('invalid login credentials')) {
      return 'login_invalid_credentials'.tr();
    }
    if (msg.contains('email not confirmed')) {
      return 'login_email_not_confirmed'.tr();
    }
    return 'login_failed_generic'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    // Scaffold 안에서는 viewInsets가 제거되므로 여기서 읽는다.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Figma: 키보드 없을 때 CTA 하단이 화면 아래 100(752/852)이고 그 아래 56에
    // 가입 링크가 붙는다(다른 화면의 y752 보조 행과 같은 자리). 키보드 위 12.
    final ctaBottom = keyboardOpen
        ? 12.0
        : (100.0 - safeBottom - 56).clamp(10.0, double.infinity);
    final passwordErrorInRow = _passwordError;

    return Scaffold(
      backgroundColor: glass.surfaceHeader,
      body: SafeArea(
        child: Stack(children: [
          AutofillGroup(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  12, 36, 12, ctaBottom + 56 + (keyboardOpen ? 0 : 56) + 24),
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo_vivanaut_wordmark.png',
                    key: const ValueKey('login-logo'),
                    width: 200,
                    height: 48.64,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                VivaTextField(
                  fieldKey: const ValueKey('login-email'),
                  label: 'login_id_label'.tr(),
                  controller: _emailController,
                  hintText: 'login_id_hint'.tr(),
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                VivaTextField(
                  fieldKey: const ValueKey('login-password'),
                  label: 'auth_password'.tr(),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hintText: 'login_password_rule'.tr(),
                  errorText: passwordErrorInRow,
                  showErrorBelow: false,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _login(),
                  gapBelow: 12,
                  suffix: GestureDetector(
                    key: const ValueKey('login-password-visibility'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Semantics(
                      button: true,
                      label: (_obscurePassword
                              ? 'login_show_password'
                              : 'login_hide_password')
                          .tr(),
                      child: FigmaIcon.tinted(
                          _obscurePassword
                              ? 'redesign_v2/visibility'
                              : 'redesign_v2/visibility_off',
                          size: 24,
                          color: glass.deviceOff),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 24,
                    child: Row(children: [
                      VivaCheckRow(
                          key: const ValueKey('login-auto-login'),
                          label: 'login_auto_login'.tr(),
                          value: _autoLogin,
                          onChanged: (v) => setState(() => _autoLogin = v)),
                      const SizedBox(width: 8),
                      if (passwordErrorInRow != null)
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(passwordErrorInRow,
                                key: const ValueKey('login-password-error'),
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: vivaFieldErrorText(context)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: ctaBottom,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const ValueKey('login-submit'),
                  onPressed: _canSubmit ? _login : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: glass.textPrimary,
                      foregroundColor: VivaColors.fillBack,
                      disabledBackgroundColor: glass.border,
                      disabledForegroundColor: VivaColors.fillBack,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: vivaFieldText(context).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 28 / 18,
                          letterSpacing: -0.36)),
                  child: Text(
                      (_isLoading ? 'login_in_progress' : 'auth_login').tr()),
                ),
              ),
              // Figma에 가입 진입점이 없어(계획 B4) 다른 화면의 y752 보조 행
              // 자리에 텍스트 링크로 둔다. 키보드가 열리면 숨긴다.
              if (!keyboardOpen)
                SizedBox(
                  height: 56,
                  child: TextButton(
                    key: const ValueKey('login-signup'),
                    onPressed: () => context.push('/signup'),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        foregroundColor: glass.textSecondary,
                        textStyle: vivaFieldText(context).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 19.09 / 16,
                            letterSpacing: -0.32)),
                    child: Text('auth_no_account'.tr()),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
