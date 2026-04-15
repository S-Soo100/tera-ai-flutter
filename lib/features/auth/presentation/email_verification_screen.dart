import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _otpCode;
    if (code.length != 6) return;

    setState(() => _isVerifying = true);
    try {
      await ref.read(authRepositoryProvider).verifyOTP(
            email: widget.email,
            token: code,
          );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        // 코드 초기화
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupOTP(email: widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth_verify_resent'.tr())),
        );
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otpCode.length == 6) {
      _verify();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
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
                const SizedBox(height: 40),

                // 6자리 코드 입력
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 48,
                      margin: EdgeInsets.only(
                        left: i == 0 ? 0 : 8,
                        right: i == 2 ? 12 : 0, // 3-3 그룹 간격
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) => _onKeyEvent(i, event),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: theme.textTheme.headlineSmall,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // 인증 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _isVerifying || _otpCode.length != 6 ? null : _verify,
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('auth_verify_button'.tr()),
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
