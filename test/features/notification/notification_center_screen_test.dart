import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/presentation/notification_center_screen.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/shared/widgets/skeleton_loading.dart';
import 'notification_repository_test.dart';
import 'notification_test_host.dart';

class ControlledNotificationStore extends MemoryNotificationStore {
  final source = StreamController<List<Map<String, Object?>>>.broadcast();
  @override
  Stream<List<Map<String, Object?>>> watch(String userId) => source.stream;
}

void main() {
  setUpAll(initializeNotificationLocalization);
  Future<ProviderContainer> pump(
      WidgetTester tester, MemoryNotificationStore store,
      {PushPermission permission = PushPermission.authorized}) async {
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationCenterScreen()),
      GoRoute(
          path: '/env-detail',
          builder: (_, __) {
            expect(store.operations, contains('read:n1:a'));
            return const Scaffold(body: Text('environment'));
          }),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => notificationUser('a')),
          notificationRepositoryProvider.overrideWithValue(
              NotificationRepository(store, currentUserId: () => 'a')),
          pushPermissionProvider.overrideWith((ref) => permission),
        ],
        child: localizedNotificationHost((context) => MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
            ))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return ProviderScope.containerOf(
        tester.element(find.byType(NotificationCenterScreen)));
  }

  testWidgets('loading skeleton, error and retry, then localized empty state',
      (tester) async {
    final store = ControlledNotificationStore();
    addTearDown(store.source.close);
    addTearDown(store.changes.close);
    await pump(tester, store);
    expect(find.byType(SkeletonPageLoading), findsOneWidget);
    store.source.addError(StateError('network'));
    await tester.pumpAndSettle();
    expect(find.text('알림을 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    store.source.add([]);
    await tester.pumpAndSettle();
    expect(find.text('아직 알림이 없어요'), findsOneWidget);
  });
  testWidgets('unread row marks only its id before navigation', (tester) async {
    final store = MemoryNotificationStore()
      ..rows.add(notificationRow('n1', 'a', '2026-09-15T00:00:00Z'));
    addTearDown(store.changes.close);
    await pump(tester, store);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification_unread_n1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification_n1')));
    await tester.pumpAndSettle();
    expect(find.text('environment'), findsOneWidget);
  });
  testWidgets(
      'mark all clears the derived unread count and unknown kind stays on center',
      (tester) async {
    final row = notificationRow('n1', 'a', '2026-09-15T00:00:00Z')
      ..['kind'] = 'future.kind';
    final store = MemoryNotificationStore()..rows.add(row);
    addTearDown(store.changes.close);
    final container = await pump(tester, store);
    await tester.pumpAndSettle();
    expect(container.read(unreadNotificationCountProvider), 1);
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(find.byKey(const Key('notification_unread_n1')), findsNothing);
    await tester.tap(find.byKey(const Key('notification_n1')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationCenterScreen), findsOneWidget);
  });
  testWidgets('denied permission keeps an enable action in notification center',
      (tester) async {
    final store = MemoryNotificationStore();
    addTearDown(store.changes.close);
    await pump(tester, store, permission: PushPermission.denied);
    await tester.pumpAndSettle();
    expect(find.text('알림 켜기'), findsOneWidget);
  });
}
