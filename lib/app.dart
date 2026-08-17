import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/connectivity_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'shared/widgets/offline_overlay.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      // 다크/라이트 2벌(2026-08-14 오후 — 오전의 전역 다크 고정을 철회).
      // 솔리드 문법은 같고 값만 반전한다(`GlassPalette`). 모드는 프로필의
      // "화면 모드"(시스템/라이트/다크)로 고르고 Hive에 남는다.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final online = ref.watch(connectivityProvider).valueOrNull ?? true;
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(1.15)),
          child: Stack(
            children: [
              child!,
              if (!online)
                Positioned.fill(
                  child: OfflineOverlay(
                    onRetry: () => ref.invalidate(connectivityProvider),
                  ),
                ),
            ],
          ),
        );
      },
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
