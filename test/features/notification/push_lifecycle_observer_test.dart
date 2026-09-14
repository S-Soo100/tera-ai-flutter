import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/notification/domain/push_lifecycle_controller.dart';
import 'package:vivanaut/features/notification/presentation/push_lifecycle_observer.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'notification_repository_test.dart';
import 'push_lifecycle_controller_test.dart';

void main() {
  testWidgets(
      'auth null event is delivered even if a new login arrives before the next frame',
      (tester) async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger = tester.binding.defaultBinaryMessenger;
    const notificationsChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const timezoneChannel = MethodChannel('flutter_timezone');
    messenger.setMockMethodCallHandler(
        timezoneChannel, (_) async => 'Asia/Seoul');
    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(timezoneChannel, null);
      messenger.setMockMethodCallHandler(notificationsChannel, null);
    });
    final auth = StateProvider<User?>((ref) => notificationUser('a'));
    final devices = RecordingPushDevices();
    final messaging = FakePushMessaging()..lifecycleEvents = devices.operations;
    final controller = PushLifecycleController(
        messaging: messaging,
        devices: devices,
        preferences: MemoryPushPreferences(),
        appVersion: () async => '1+1',
        locale: () => 'ko',
        findNotification: (_, __) async => null,
        markRead: (_) async {},
        display: (_) async {},
        navigate: (_) {},
        permissionChanged: (_) {},
        reportError: (_) {});
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(auth)),
      pushMessagingProvider.overrideWithValue(messaging),
      pushLifecycleControllerProvider.overrideWithValue(controller),
    ]);
    final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const Scaffold())]);
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    addTearDown(messaging.close);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) =>
              PushLifecycleObserver(router: router, child: child!),
        )));
    await tester.pumpAndSettle();
    expect(
        devices.operations
            .any((operation) => operation.startsWith('register:a:')),
        isTrue);
    devices.operations.clear();
    container.read(auth.notifier).state = null;
    expect(container.read(currentUserProvider), isNull);
    container.read(auth.notifier).state = notificationUser('b');
    expect(container.read(currentUserProvider)?.id, 'b');
    await tester.pumpAndSettle();
    expect(messaging.deletes, 1);
    expect(devices.operations, [
      'deleteToken',
      'register:b:4da7f48b-0000-4000-8000-111111111111:new-login-token:1+1:ko'
    ]);
  });
}
