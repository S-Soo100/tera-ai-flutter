import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/notification/presentation/push_lifecycle_observer.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/features/app_update/presentation/app_update_providers.dart';
import 'package:vivanaut/shared/services/local_notifications.dart';
import 'notification_repository_test.dart';
import 'push_lifecycle_controller_test.dart';

const _mine = '4da7f48b-0000-4000-8000-111111111111';
const _other = '4da7f48b-0000-4000-8000-222222222222';

/// iOS처럼 FCM이 꺼진 기기 — 로컬 알림 탭은 그래도 처리돼야 한다.
class _FcmOffMessaging extends FakePushMessaging {
  @override
  bool get supported => false;
}

class _Harness {
  _Harness(this.container, this.router, this.auth);
  final ProviderContainer container;
  final GoRouter router;
  final StateProvider<User?> auth;

  /// 맨 위 화면 — 주소는 push를 반영하지 않으므로 스택으로 본다.
  String get path => stack.last;
  List<String> get stack => router.routerDelegate.currentConfiguration.matches
      .map((m) => m.matchedLocation)
      .toList();
  String? get selected => container.read(selectedHomeDeviceIdProvider);
  void signIn(String? id) => container.read(auth.notifier).state =
      id == null ? null : notificationUser(id);
  void tap(String payload) => LocalNotifications.instance.onTap!(payload);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  String? user = 'a',
  String initial = '/home',
  Object? launchPayload,
  Future<Iterable<String>> Function()? devices,
  bool updateRequired = false,
}) async {
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
      return launchPayload == null
          ? {'notificationLaunchedApp': false}
          : {
              'notificationLaunchedApp': true,
              'notificationResponse': {
                'notificationResponseType': 0,
                'payload': launchPayload,
              },
            };
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(timezoneChannel, null);
    messenger.setMockMethodCallHandler(notificationsChannel, null);
  });
  final auth =
      StateProvider<User?>((ref) => user == null ? null : notificationUser(user));
  final messaging = _FcmOffMessaging();
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWith((ref) => ref.watch(auth)),
    pushMessagingProvider.overrideWithValue(messaging),
    updateRequiredProvider.overrideWith((ref) => updateRequired),
    // FCM이 꺼져 있으면 컨트롤러(Supabase·Firebase 배선)를 만들지 않아야 한다.
    pushLifecycleControllerProvider
        .overrideWith((ref) => throw StateError('controller must not be read')),
    notificationDeviceIdsProvider
        .overrideWithValue(devices ?? () async => const [_mine]),
    selectedHomeDeviceIdProvider.overrideWith((ref) => null),
  ]);
  Widget page(String name) => Scaffold(body: Text(name));
  final router = GoRouter(initialLocation: initial, routes: [
    for (final p in [
      '/splash',
      '/login',
      '/update-required',
      '/home',
      '/home/routines',
      '/crecam',
      '/env-detail',
    ])
      GoRoute(path: p, builder: (_, __) => page(p)),
  ]);
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
  return _Harness(container, router, auth);
}

void main() {
  // 첫 테스트여야 한다 — 앱을 띄운 알림은 프로세스당 한 번만 전달된다.
  testWidgets(
      'cold launch from a schedule alarm while logged out waits for login, '
      'then selects and opens routines without /login in the stack',
      (tester) async {
    final h = await _pump(tester,
        user: null, initial: '/login', launchPayload: 'sched:$_mine');
    expect(h.path, '/login');
    expect(h.selected, isNull);
    h.signIn('a');
    await tester.pumpAndSettle();
    // 로그인 직후 아직 /login — redirect(홈 이동)보다 먼저 옮기지 않는다.
    expect(h.path, '/login');
    h.router.go('/home');
    await tester.pumpAndSettle();
    expect(h.selected, _mine);
    expect(h.path, '/home/routines');
    expect(h.stack, ['/home', '/home/routines']);
  });

  testWidgets('fan alarm with FCM off selects the device and goes to home tab',
      (tester) async {
    final h = await _pump(tester, initial: '/env-detail');
    h.tap('fan:$_mine');
    await tester.pumpAndSettle();
    expect(h.selected, _mine);
    expect(h.path, '/home');
    // 탭 경로는 go — 이전 화면 위에 홈을 쌓지 않는다.
    expect(h.stack, ['/home']);
  });

  testWidgets('fan alarm for a device not mine keeps the selection, goes home',
      (tester) async {
    final h = await _pump(tester, initial: '/crecam');
    h.tap('fan:$_other');
    await tester.pumpAndSettle();
    expect(h.selected, isNull);
    expect(h.path, '/home');
  });

  testWidgets('schedule alarm for a device not mine goes home, not routines',
      (tester) async {
    final h = await _pump(tester, initial: '/crecam');
    h.tap('sched:$_other');
    await tester.pumpAndSettle();
    expect(h.selected, isNull);
    expect(h.path, '/home');
  });

  testWidgets('schedule alarm already on home pushes routines on top',
      (tester) async {
    final h = await _pump(tester);
    h.tap('sched:$_mine');
    await tester.pumpAndSettle();
    expect(h.selected, _mine);
    expect(h.stack, ['/home', '/home/routines']);
  });

  testWidgets(
      'fan alarm while routines is pushed over home still returns to home '
      '(the address bar does not reflect push)', (tester) async {
    final h = await _pump(tester);
    unawaited(h.router.push<void>('/home/routines'));
    await tester.pumpAndSettle();
    expect(h.router.routeInformationProvider.value.uri.path, '/home');
    h.tap('fan:$_mine');
    await tester.pumpAndSettle();
    expect(h.stack, ['/home']);
    expect(h.selected, _mine);
  });

  testWidgets('forced update page keeps the tap held until it is lifted',
      (tester) async {
    final h = await _pump(tester, initial: '/update-required');
    h.tap('sched:$_mine');
    await tester.pumpAndSettle();
    expect(h.path, '/update-required');
    expect(h.selected, isNull);
    h.router.go('/splash');
    await tester.pumpAndSettle();
    expect(h.path, '/splash');
    h.router.go('/home');
    await tester.pumpAndSettle();
    expect(h.selected, _mine);
    expect(h.path, '/home/routines');
  });

  testWidgets('account change while my devices load drops the tap',
      (tester) async {
    final devices = Completer<Iterable<String>>();
    final h = await _pump(tester,
        initial: '/crecam', devices: () => devices.future);
    h.tap('sched:$_mine');
    await tester.pump();
    h.signIn('b');
    await tester.pump();
    devices.complete(const [_mine]);
    await tester.pumpAndSettle();
    expect(h.selected, isNull);
    expect(h.path, '/crecam');
  });

  testWidgets('server push payload with FCM off is ignored safely',
      (tester) async {
    final h = await _pump(tester, initial: '/crecam');
    h.tap('{"notification_id":"n1","kind":"x","route":"/env-detail"}');
    h.tap('garbage');
    await tester.pumpAndSettle();
    expect(h.path, '/crecam');
  });

  testWidgets(
      'forced update in effect when the tap is processed: no navigation '
      '(review 11-18 — push would stack the update page)', (tester) async {
    final h = await _pump(tester, initial: '/env-detail', updateRequired: true);
    h.tap('fan:$_mine');
    await tester.pumpAndSettle();
    expect(h.path, '/env-detail');
  });
}
