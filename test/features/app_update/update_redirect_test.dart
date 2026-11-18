import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/router/tab_branches.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/app_update/data/app_release_policy_repository.dart';
import 'package:vivanaut/features/app_update/data/update_dismissal_store.dart';
import 'package:vivanaut/features/app_update/domain/update_policy.dart';
import 'package:vivanaut/features/app_update/presentation/app_update_providers.dart';
import 'package:vivanaut/shared/providers/external_url_launcher.dart';

const _post = '/community-player/0b7f6a2e-6f2d-4c43-9a49-8a8f3c2f1e10';

class _NullRepository implements AppReleasePolicyRepository {
  @override
  Future<UpdatePolicy?> fetch(String platform) async => null;
}

class _MemoryDismissals implements UpdateDismissalStore {
  @override
  int? load() => null;
  @override
  Future<void> save(int build) async {}
}

class _Refresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

List<Override> _overrides() => [
      appReleasePolicyRepositoryProvider.overrideWithValue(_NullRepository()),
      updateDismissalStoreProvider.overrideWithValue(_MemoryDismissals()),
      appBuildInfoProvider.overrideWith((ref) async => const AppBuildInfo(
          packageName: kUpdateTargetPackage,
          buildNumber: '530',
          platform: TargetPlatform.android)),
      externalUrlLauncherProvider.overrideWithValue((_) async => true),
    ];

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('resolveAppRedirect — 강제 업데이트 규칙', () {
    test('강제면 스플래시를 뺀 모든 경로가 업데이트 화면으로', () {
      for (final path in [
        '/home',
        '/home/routines',
        _post,
        '/login',
        '/notifications',
        '/crecam/highlights',
      ]) {
        for (final authed in [true, false]) {
          expect(
              resolveAppRedirect(path,
                  authenticated: authed, updateRequired: true),
              kUpdateRequiredPath,
              reason: '$path authed=$authed');
        }
      }
    });

    test('강제여도 스플래시는 건드리지 않는다(시작 흐름 유지)', () {
      expect(
          resolveAppRedirect('/splash',
              authenticated: false, updateRequired: true),
          isNull);
    });

    test('강제면 업데이트 화면에 머문다 — 자기 자신으로 다시 보내지 않아 루프 없음', () {
      expect(
          resolveAppRedirect(kUpdateRequiredPath,
              authenticated: true, updateRequired: true),
          isNull);
    });

    test('풀리면 스플래시를 다시 거치지 않고 로그인 여부대로 홈·로그인으로', () {
      // 스플래시는 "앱 시작" 로직(자동 로그인 끔 → 로그아웃)을 다시 돌린다 —
      // 실행 중 해제에 거치면 쓰던 세션이 끊긴다(코드 리뷰 2026-11-18).
      expect(
          resolveAppRedirect(kUpdateRequiredPath,
              authenticated: true, updateRequired: false),
          '/home');
      expect(
          resolveAppRedirect(kUpdateRequiredPath,
              authenticated: false, updateRequired: false),
          '/login');
    });

    test('강제가 아니면 기존 규칙 그대로', () {
      expect(
          resolveAppRedirect('/crecam',
              authenticated: false, updateRequired: false),
          '/login');
      expect(
          resolveAppRedirect('/login',
              authenticated: true, updateRequired: false),
          '/home');
      expect(
          resolveAppRedirect('/home/routines',
              authenticated: true, updateRequired: false),
          isNull);
    });

    test('업데이트 화면은 공개 경로(로그인 전에도 뜬다)', () {
      expect(kPublicPaths, contains(kUpdateRequiredPath));
    });
  });

  group('실제 앱 라우터', () {
    late bool required;
    late _Refresh refresh;
    late GoRouter router;
    late List<String> systemCalls;

    Future<void> pumpApp(WidgetTester tester) async {
      required = true;
      refresh = _Refresh();
      router = buildAppRouter(
          isAuthenticated: () => true,
          isUpdateRequired: () => required,
          refreshListenable: refresh);
      systemCalls = [];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        systemCalls.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(),
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    }

    Future<void> finish(WidgetTester tester) async {
      // 스플래시의 1초 지연이 끝나도 화면이 이미 내려가 있어 아무것도 안 한다.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      router.dispose();
    }

    testWidgets('강제면 /home·/home/routines·커뮤니티 재생 딥링크가 업데이트 화면으로',
        (tester) async {
      await pumpApp(tester);
      router.go('/home');
      await tester.pumpAndSettle();
      expect(_location(router), kUpdateRequiredPath);

      router.push('/home/routines');
      await tester.pumpAndSettle();
      expect(_location(router), kUpdateRequiredPath);

      router.go(_post);
      await tester.pumpAndSettle();
      expect(_location(router), kUpdateRequiredPath);
      expect(find.byKey(const Key('update_required_screen')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('업데이트 화면은 스택의 유일한 페이지 — 뒤로 가기는 앱 종료만', (tester) async {
      await pumpApp(tester);
      router.go('/home');
      await tester.pumpAndSettle();
      router.push('/home/routines');
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);

      // 시스템 뒤로 가기: 앱 안에서 처리할 페이지가 없어 SystemNavigator.pop
      // (= 앱 닫기)으로 넘어간다. 업데이트 화면은 그대로.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(systemCalls, contains('SystemNavigator.pop'));
      expect(_location(router), kUpdateRequiredPath);
      await finish(tester);
    });

    testWidgets('풀리면 원래 흐름(로그인 상태라 홈)으로 — redirect 루프 없음', (tester) async {
      await pumpApp(tester);
      router.go('/home');
      await tester.pumpAndSettle();
      expect(_location(router), kUpdateRequiredPath);

      required = false;
      refresh.notify();
      await tester.pump();
      await tester.pump();
      expect(_location(router), '/home');
      expect(router.canPop(), isFalse);
      await finish(tester);
    });
  });

  group('강제로 바뀌면 열려 있던 스택을 통째로 걷는다', () {
    testWidgets('push로 쌓인 화면 위에서 강제 → 업데이트 화면 하나만 남는다', (tester) async {
      var required = false;
      final refresh = _Refresh();
      Widget page(String name) => Scaffold(body: Text(name, key: Key(name)));
      final router = GoRouter(
        initialLocation: '/home',
        refreshListenable: refresh,
        redirect: (context, state) => resolveAppRedirect(state.uri.path,
            authenticated: true, updateRequired: required),
        routes: [
          GoRoute(path: '/splash', builder: (_, __) => page('splash')),
          GoRoute(path: '/home', builder: (_, __) => page('home'), routes: [
            GoRoute(path: 'routines', builder: (_, __) => page('routines')),
          ]),
          GoRoute(
              path: '/community-player/:postId',
              builder: (_, __) => page('player')),
          GoRoute(
              path: kUpdateRequiredPath, builder: (_, __) => page('update')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/home/routines');
      await tester.pumpAndSettle();
      router.push(_post);
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      required = true;
      refresh.notify();
      await tester.pumpAndSettle();
      expect(_location(router), kUpdateRequiredPath);
      expect(find.byKey(const Key('update')), findsOneWidget);
      expect(
          find.byKey(const Key('routines'), skipOffstage: false), findsNothing);
      expect(router.canPop(), isFalse);

      required = false;
      refresh.notify();
      await tester.pumpAndSettle();
      expect(_location(router), '/home');
    });
  });
}
