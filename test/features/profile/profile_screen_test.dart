import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/data/auth_repository.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/community/presentation/community_providers.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/domain/push_lifecycle_controller.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/features/profile/domain/user_profile.dart';
import 'package:vivanaut/features/profile/presentation/account_screen.dart';
import 'package:vivanaut/features/profile/presentation/profile_providers.dart';
import 'package:vivanaut/features/profile/presentation/profile_screen.dart';
import '../notification/notification_repository_test.dart';
import '../notification/push_lifecycle_controller_test.dart';

class EmptyProfile extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => null;
}

class RecordingAuth extends AuthRepository {
  RecordingAuth(this.operations)
      : super(SupabaseClient('https://example.test', 'test-anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final List<String> operations;
  @override
  Future<void> signOut() async {
    operations.add('signout');
  }
}

void main() {
  testWidgets(
      'mypage red dot derives from live unread rows; account logout modal deactivates before auth',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryNotificationStore()
      ..rows.add(notificationRow('n1', 'a', '2026-09-15T00:00:00Z'));
    final repo = NotificationRepository(store, currentUserId: () => 'a');
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
    await controller.setUser('a');
    devices.operations.clear();
    addTearDown(store.changes.close);
    addTearDown(messaging.close);
    addTearDown(controller.dispose);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/profile/account',
          builder: (_, __) => const AccountScreen()),
      GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('login'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWith((ref) => notificationUser('a')),
      profileNotifierProvider.overrideWith(EmptyProfile.new),
      appVersionProvider.overrideWith((ref) async => '1+1'),
      blockedProfilesProvider.overrideWith((ref) async => const []),
      notificationRepositoryProvider.overrideWithValue(repo),
      pushLifecycleControllerProvider.overrideWithValue(controller),
      authRepositoryProvider
          .overrideWithValue(RecordingAuth(devices.operations)),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_notifications_dot')), findsOneWidget);
    await repo.markAllRead('a');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_notifications_dot')), findsNothing);
    // 로그아웃은 내 계정 화면의 CTA → 모달 확인.
    await tester.tap(find.byKey(ProfileScreen.accountRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AccountScreen.logoutKey));
    await tester.pumpAndSettle();
    expect(find.text('account_logout_question'), findsOneWidget);
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(devices.operations, ['deactivate', 'deleteToken', 'signout']);
    expect(find.text('login'), findsOneWidget);
  });
}
