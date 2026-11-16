// 회원 탈퇴 — terra-server `POST /account/delete`(gwanhun/terra-server#67,
// 회신 docs/BACKEND_REPLY_DELETE_ACCOUNT_2026-11-17.md §3) 응답별 동작.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/auth/data/auth_repository.dart';
import 'package:vivanaut/features/notification/domain/push_lifecycle_controller.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/features/profile/presentation/withdraw_screen.dart';

import '../notification/push_lifecycle_controller_test.dart'
    show FakePushMessaging, MemoryPushPreferences, RecordingPushDevices;

class _Session implements AuthSession {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<bool> recoverFromUnauthorized() async => false;
}

/// POST 호출을 기록하고, [error]가 있으면 던진다.
class _FakeRest extends TerraRestClient {
  _FakeRest({this.error})
      : super(baseUrl: 'https://terra.test', session: _Session());
  final Object? error;
  final posts = <(String, Map<String, dynamic>?)>[];

  @override
  Future<Object?> post(String path, [Map<String, dynamic>? body]) async {
    posts.add((path, body));
    if (error != null) throw error!;
    return {'deleted': true};
  }
}

SupabaseClient _supabase() => SupabaseClient('https://example.test', 'anon',
    authOptions: const AuthClientOptions(autoRefreshToken: false));

class _RecordingAuth extends AuthRepository {
  _RecordingAuth(this.ops, _FakeRest rest)
      : super(_supabase(), restClient: () => rest);
  final List<String> ops;
  @override
  Future<void> signOut() async => ops.add('signout');
}

Future<_FakeRest> _pump(WidgetTester tester, {Object? error}) async {
  final rest = _FakeRest(error: error);
  final ops = <String>[];
  final devices = RecordingPushDevices();
  final messaging = FakePushMessaging();
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
  addTearDown(messaging.close);
  addTearDown(controller.dispose);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const WithdrawScreen()),
    GoRoute(
        path: '/login', builder: (_, __) => const Scaffold(body: Text('login'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_RecordingAuth(ops, rest)),
    pushLifecycleControllerProvider.overrideWithValue(controller),
  ], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(WithdrawScreen.submitKey));
  await tester.pumpAndSettle();
  return rest;
}

void main() {
  test('deleteAccount는 terra-server POST /account/delete를 본문 없이 부른다',
      () async {
    final rest = _FakeRest();
    await AuthRepository(_supabase(), restClient: () => rest).deleteAccount();
    expect(rest.posts, [('/account/delete', null)]);
  });

  testWidgets('200 — 로그아웃 후 로그인 화면', (tester) async {
    final rest = await _pump(tester);
    expect(rest.posts.single.$1, '/account/delete');
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('409 admin_account — 앱에서 탈퇴할 수 없다고 안내', (tester) async {
    await _pump(tester,
        error: const TerraRestException(409, '{"code":"admin_account"}'));
    expect(find.text('withdraw_not_allowed'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });

  testWidgets('404 — 서버에 아직 없으면 준비 안 됨 + 웹 요청 안내', (tester) async {
    await _pump(tester, error: const TerraRestException(404, 'Not Found'));
    expect(find.text('withdraw_not_ready'), findsOneWidget);
  });

  testWidgets('500 — 실패, 다시 시도 안내', (tester) async {
    await _pump(tester,
        error: const TerraRestException(500, '{"code":"unlink_failed"}'));
    expect(find.text('withdraw_failed'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });
}
