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
  for (final scenario in [
    (name: 'coalesced A to B', initial: 'a', transitions: <String?>['b']),
    (name: 'A to null', initial: 'a', transitions: <String?>[null]),
    (name: 'null to B', initial: null, transitions: <String?>['b']),
    (
      name: 'same-frame A to null to B without forced provider reads',
      initial: 'a',
      transitions: <String?>[null, 'b']
    ),
  ]) {
    testWidgets('auth transport lifecycle: ${scenario.name}', (tester) async {
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
      final auth = StateProvider<User?>((ref) => scenario.initial == null
          ? null
          : notificationUser(scenario.initial!));
      final devices = RecordingPushDevices();
      final messaging = FakePushMessaging()
        ..lifecycleEvents = devices.operations;
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
          scenario.initial != null);
      devices.operations.clear();
      for (final userId in scenario.transitions) {
        container.read(auth.notifier).state =
            userId == null ? null : notificationUser(userId);
      }
      await tester.pumpAndSettle();
      expect(messaging.deletes, scenario.initial == null ? 0 : 1);
      expect(devices.operations, [
        if (scenario.initial != null) 'deleteToken',
        if (scenario.transitions.last != null)
          'register:b:4da7f48b-0000-4000-8000-111111111111:${scenario.initial == null ? 'test-token' : 'new-login-token'}:1+1:ko'
      ]);
    });
  }
}
