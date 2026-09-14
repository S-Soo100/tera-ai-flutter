import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/domain/push_lifecycle_controller.dart';
import 'package:vivanaut/features/notification/presentation/push_permission_prompt.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'notification_repository_test.dart';
import 'notification_test_host.dart';
import 'push_lifecycle_controller_test.dart';

void main() {
  setUpAll(initializeNotificationLocalization);
  Future<(FakePushMessaging, MemoryPushPreferences)> pump(WidgetTester tester,
      {bool seen = false, bool signedIn = true}) async {
    final messaging = FakePushMessaging()..permission = PushPermission.denied;
    final preferences = MemoryPushPreferences()..seen = seen;
    final controller = PushLifecycleController(
        messaging: messaging,
        devices: RecordingPushDevices(),
        preferences: preferences,
        appVersion: () async => '1+1',
        locale: () => 'ko',
        findNotification: (_, __) async => null,
        markRead: (_) async {},
        display: (_) async {},
        navigate: (_) {},
        permissionChanged: (_) {},
        reportError: (_) {});
    await controller.setUser(signedIn ? 'a' : null);
    addTearDown(controller.dispose);
    addTearDown(messaging.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider
              .overrideWith((ref) => signedIn ? notificationUser('a') : null),
          pushPreferencesProvider.overrideWithValue(preferences),
          pushPermissionProvider.overrideWith((ref) => PushPermission.denied),
          pushMessagingProvider.overrideWithValue(messaging),
          pushLifecycleControllerProvider.overrideWithValue(controller),
        ],
        child: localizedNotificationHost((context) => MaterialApp(
              navigatorKey: navigatorKey,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              builder: (_, child) => PushPermissionPrompt(
                  navigatorKey: navigatorKey, child: child!),
              home: const Scaffold(body: Text('home')),
            ))));
    await tester.pumpAndSettle();
    return (messaging, preferences);
  }

  testWidgets(
      'eligible signed-in launch explains first; later records seen without OS prompt',
      (tester) async {
    final (messaging, preferences) = await pump(tester);
    expect(find.text('하이라이트·사육장 동작·안전 알림을 받아보세요'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(preferences.seen, isTrue);
    expect(messaging.requests, 0);
    expect(find.text('home'), findsOneWidget);
  });
  testWidgets('enable button invokes the OS permission after explanation',
      (tester) async {
    final (messaging, preferences) = await pump(tester);
    await tester.tap(find.text('알림 켜기'));
    await tester.pumpAndSettle();
    expect(messaging.requests, 1);
    expect(preferences.seen, isTrue);
  });
  testWidgets('seen explanation is not repeated', (tester) async {
    await pump(tester, seen: true);
    expect(find.text('나중에'), findsNothing);
  });
  testWidgets('signed-out launches do not ask permission', (tester) async {
    await pump(tester, signedIn: false);
    expect(find.text('나중에'), findsNothing);
  });
}
