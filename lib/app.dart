import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/connectivity_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/offline_overlay.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      // A안 Liquid Glass는 **단일 룩**이다 — 모든 화면이 어두운 월페이퍼 위
      // 유리 표면이라, 시스템 라이트/다크를 따르면 절반의 위젯이 안 읽힌다.
      // 화면마다 Theme(data: AppTheme.dark)로 감싸던 것을 여기로 올렸다(2026-08-14).
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
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
