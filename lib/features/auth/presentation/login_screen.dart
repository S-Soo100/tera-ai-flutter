import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final lastEmail =
        Hive.box('app_settings').get('last_login_email') as String?;
    if (lastEmail != null) {
      _emailController.text = lastEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: _passwordController.text,
          );
      await Hive.box('app_settings').put('last_login_email', email);
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 로고
                  Icon(Icons.pets, size: 64, color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Tera AI',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'auth_login_subtitle'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // 이메일
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'auth_email'.tr(),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'auth_email_required'.tr();
                      }
                      if (!v.contains('@')) return 'auth_email_invalid'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'auth_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'auth_password_required'.tr();
                      }
                      if (v.length < 6) return 'auth_password_min_length'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 로그인 버튼
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('auth_login'.tr()),
                  ),
                  const SizedBox(height: 16),

                  // 회원가입 링크
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: Text('auth_no_account'.tr()),
                  ),

                  // 둘러보기
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      'auth_browse'.tr(),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
