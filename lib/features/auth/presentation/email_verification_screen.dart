import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import 'auth_error_text.dart';
import 'widgets/otp_code_field.dart';

/// 가입 이메일 인증 — 6자리 코드.
///
/// 입력은 [OtpCodeField] 하나(붙여넣기·자동완성 지원, UX-03 2026-10-01).
/// 6자리가 채워지면 자동으로 확인하고, 확인 중에는 자동 제출·버튼 모두 한 번만
/// 나간다. 실패하면 코드를 비우고 오류를 칸 아래에 남겨 바로 다시 입력하거나
/// 재전송할 수 있다.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // 버튼 활성(6자리)과 오류 지우기를 입력마다 반영한다.
    _code.addListener(() {
      if (!mounted) return;
      setState(() {
        if (_code.text.isNotEmpty) _error = null;
      });
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _verify() async {
    final code = _code.text;
    // 자동 제출과 버튼이 겹쳐도 요청은 한 번만(UX-03).
    if (_isVerifying || code.length != OtpCodeField.length) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOTP(
            email: widget.email,
            token: code,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() => _error = authErrorText(e));
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupOTP(email: widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth_verify_resent'.tr())),
        );
        _code.clear();
        setState(() => _error = null);
        _startCooldown();
      }
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/signup'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_outlined,
                    size: 64, color: colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'auth_verify_title'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'auth_verify_description'.tr(args: [widget.email]),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'auth_otp_paste_hint'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OtpCodeField(
                  controller: _code,
                  focusNode: _focus,
                  onCompleted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const Key('otp-error'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // 인증 버튼 — 진행 중엔 문구로 알린다(로딩 원형 표시 금지 규칙).
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('otp-verify'),
                    onPressed:
                        _isVerifying || _code.text.length != OtpCodeField.length
                            ? null
                            : _verify,
                    child: Text((_isVerifying
                            ? 'auth_verify_in_progress'
                            : 'auth_verify_button')
                        .tr()),
                  ),
                ),
                const SizedBox(height: 16),

                // 재전송
                TextButton(
                  onPressed:
                      _resendCooldown > 0 || _isResending ? null : _resend,
                  child: Text(
                    _resendCooldown > 0
                        ? 'auth_verify_resend_cooldown'
                            .tr(args: ['$_resendCooldown'])
                        : 'auth_verify_resend'.tr(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
