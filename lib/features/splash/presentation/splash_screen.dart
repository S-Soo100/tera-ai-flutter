import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/login_prefs_repository.dart';
import '../../notification/presentation/push_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    // 로그인 화면의 "자동 로그인"을 끈 채 로그인했으면 다음 실행에서 세션을
    // 끊고 다시 묻는다(2026-09-16 Figma 로그인 재설계, 계획 B3).
    if (session != null && !ref.read(loginPrefsProvider).autoLogin) {
      try {
        // 내 계정 화면의 로그아웃과 같은 경로 — 푸시 기기 비활성화·토큰 삭제
        // 뒤에 signOut(리뷰 2026-09-16: 직접 signOut은 기기 행을 남긴다).
        await ref.read(pushLifecycleControllerProvider).logout(auth.signOut);
      } catch (_) {
        // 오프라인이면 서버 세션은 남아도 로컬은 지워진다 — 로그인으로 보낸다.
      }
      session = null;
      if (!mounted) return;
    }
    if (session != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 브랜드 레드 로고라 배경은 흰색이어야 대비가 산다.
    // (기존 primary 초록 배경 위 빨강은 서로 채도가 높아 탁해진다)
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 구 lockup(logo_stacked)에는 "terra ai" 워드마크가 박혀 있어
            // 심볼 단독 + 현행 브랜드명 텍스트로 조합한다 (2026-08-14 리브랜딩).
            Image.asset('assets/images/logo.png', width: 140),
            const SizedBox(height: 12),
            Text(
              'app_name'.tr(),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandRed,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'app_subtitle'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
