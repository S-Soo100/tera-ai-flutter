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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
