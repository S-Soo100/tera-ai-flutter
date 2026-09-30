import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../../shared/widgets/viva_text_field.dart';
import '../../notification/presentation/push_providers.dart';
import '../../profile/presentation/widgets/my_page_widgets.dart';
import '../data/auth_repository.dart';
import '../domain/password_rule.dart';
import 'auth_error_text.dart';
import 'widgets/otp_code_field.dart';

enum PasswordResetStep { email, code, password }

/// 비밀번호 재설정(UX-01, 2026-10-01) — 로그인 화면 "비밀번호를 잊으셨나요?".
///
/// 이메일 → 6자리 인증번호 → 새 비밀번호, 한 화면에서 단계만 바꾼다. 메일
/// 링크 대신 코드 방식이라 딥링크가 필요 없고, 앱이 꺼졌다 켜져도 메일의 코드로
/// 처음부터 다시 하면 된다.
///
/// 코드 확인에 성공하면 복구 세션(로그인 상태)이 생긴다. `/forgot-password`는
/// 로그인 상태에서 홈으로 보내는 redirect 대상이 아니라 화면이 유지된다.
/// 새 비밀번호를 저장하거나 도중에 그만두면 **로그아웃하고 로그인 화면**으로
/// 간다 — 비밀번호를 모르는 채로 로그인 상태가 남지 않게, 그리고 새 비밀번호로
/// 한 번 로그인해 보게 한다.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  static const emailKey = Key('pw_reset_email');
  static const newKey = Key('pw_reset_new');
  static const confirmKey = Key('pw_reset_confirm');
  static const submitKey = Key('pw_reset_submit');
  static const resendKey = Key('pw_reset_resend');

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _show = <Key, bool>{};

  PasswordResetStep _step = PasswordResetStep.email;
  bool _busy = false;
  String? _error;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    for (final c in [_email, _code, _next, _confirm]) {
      c.addListener(() {
        if (!mounted) return;
        setState(() {
          if (c.text.isNotEmpty) _error = null;
        });
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _emailText => _email.text.trim();

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_emailPattern.hasMatch(_emailText)) {
      setState(() => _error = 'login_email_invalid'.tr());
      return;
    }
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetCode(email: _emailText);
      if (!mounted) return;
      _code.clear();
      _startCooldown();
      setState(() => _step = PasswordResetStep.code);
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetCode(email: _emailText);
      if (!mounted) return;
      _code.clear();
      _startCooldown();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('auth_verify_resent'.tr())));
    });
  }

  Future<void> _verifyCode() async {
    final code = _code.text;
    if (code.length != OtpCodeField.length) return;
    await _run(() async {
      try {
        await ref
            .read(authRepositoryProvider)
            .verifyPasswordResetCode(email: _emailText, token: code);
      } catch (_) {
        _code.clear();
        _codeFocus.requestFocus();
        rethrow;
      }
      if (!mounted) return;
      setState(() => _step = PasswordResetStep.password);
    });
  }

  Future<void> _savePassword() async {
    if (!meetsPasswordRule(_next.text)) {
      setState(() => _error = 'login_password_rule'.tr());
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'auth_password_mismatch'.tr());
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).updatePassword(_next.text);
      if (!mounted) return;
      await _leaveSignedOut(done: true);
    });
  }

  /// 복구 세션을 닫고 로그인 화면으로. 로그아웃은 푸시 기기 정리 경로를 탄다.
  Future<void> _leaveSignedOut({required bool done}) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final auth = ref.read(authRepositoryProvider);
    try {
      await ref.read(pushLifecycleControllerProvider).logout(auth.signOut);
    } catch (_) {
      // 로그아웃 실패여도 로그인 화면으로 보낸다 — 세션이 남으면 redirect가
      // 홈으로 보낸다(이미 코드로 본인 확인을 마친 상태라 안전하다).
    }
    if (done) {
      messenger.showSnackBar(SnackBar(content: Text('pw_reset_done'.tr())));
    }
    router.go(_emailText.isEmpty
        ? '/login'
        : '/login?email=${Uri.encodeComponent(_emailText)}');
  }

  /// 뒤로: 코드 단계 → 이메일 단계, 새 비밀번호 단계 → 그만둘지 확인.
  Future<void> _back() async {
    if (_busy) return;
    switch (_step) {
      case PasswordResetStep.email:
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
      case PasswordResetStep.code:
        _cooldownTimer?.cancel();
        setState(() {
          _step = PasswordResetStep.email;
          _cooldown = 0;
          _error = null;
        });
      case PasswordResetStep.password:
        final quit = await showVivaModal(context,
            message: 'pw_reset_quit_title'.tr(),
            detail: 'pw_reset_quit_detail'.tr(),
            cancelLabel: 'pw_reset_quit_stay'.tr(),
            confirmLabel: 'pw_reset_quit_leave'.tr());
        if (quit && mounted) await _leaveSignedOut(done: false);
    }
  }

  Widget _eye(Key key) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _show[key] = !(_show[key] ?? false)),
      child: FigmaIcon.tinted(
          (_show[key] ?? false)
              ? 'redesign_v2/visibility_off'
              : 'redesign_v2/visibility',
          size: 24,
          color: context.glass.deviceOff));

  Widget _description(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: Text(text,
            style: vivaFieldText(context)
                .copyWith(fontSize: 15, color: context.glass.textSecondary)),
      );

  Widget _errorLine() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Semantics(
            liveRegion: true,
            child: Text(_error!,
                key: const Key('pw-reset-error'),
                style: vivaFieldErrorText(context)),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final (String label, VoidCallback? onPressed, Widget body) =
        switch (_step) {
      PasswordResetStep.email => (
          (_busy ? 'pw_reset_sending' : 'pw_reset_send').tr(),
          _emailText.isNotEmpty && !_busy ? _sendCode : null,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _description('pw_reset_email_desc'.tr()),
            VivaTextField(
                fieldKey: PasswordResetScreen.emailKey,
                label: 'login_id_label'.tr(),
                controller: _email,
                hintText: 'login_id_hint'.tr(),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _sendCode(),
                gapBelow: 0),
            _errorLine(),
          ]),
        ),
      PasswordResetStep.code => (
          (_busy ? 'auth_verify_in_progress' : 'common_confirm').tr(),
          _code.text.length == OtpCodeField.length && !_busy
              ? _verifyCode
              : null,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _description('pw_reset_code_desc'.tr(args: [_emailText])),
            OtpCodeField(
              controller: _code,
              focusNode: _codeFocus,
              onCompleted: (_) => _verifyCode(),
            ),
            _errorLine(),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                key: PasswordResetScreen.resendKey,
                onPressed: _cooldown > 0 || _busy ? null : _resend,
                child: Text(_cooldown > 0
                    ? 'auth_verify_resend_cooldown'.tr(args: ['$_cooldown'])
                    : 'auth_verify_resend'.tr()),
              ),
            ),
          ]),
        ),
      PasswordResetStep.password => (
          (_busy ? 'pw_reset_saving' : 'pw_reset_save').tr(),
          _next.text.isNotEmpty && _confirm.text.isNotEmpty && !_busy
              ? _savePassword
              : null,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _description('pw_reset_password_desc'.tr()),
            VivaTextField(
                fieldKey: PasswordResetScreen.newKey,
                label: 'pw_change_new'.tr(),
                controller: _next,
                hintText: 'login_password_rule'.tr(),
                obscureText: !(_show[PasswordResetScreen.newKey] ?? false),
                suffix: _eye(PasswordResetScreen.newKey),
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next),
            VivaTextField(
                fieldKey: PasswordResetScreen.confirmKey,
                label: 'pw_change_confirm'.tr(),
                controller: _confirm,
                hintText: 'login_password_rule'.tr(),
                obscureText: !(_show[PasswordResetScreen.confirmKey] ?? false),
                suffix: _eye(PasswordResetScreen.confirmKey),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _savePassword(),
                gapBelow: 0),
            _errorLine(),
          ]),
        ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: MyPageScaffold(
        title: 'pw_reset_title'.tr(),
        white: true,
        floating: MyPageCta(
            key: PasswordResetScreen.submitKey,
            label: label,
            onPressed: onPressed),
        child: body,
      ),
    );
  }
}
