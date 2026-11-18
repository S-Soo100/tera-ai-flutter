
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/tab_branches.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/app_update/data/app_release_policy_repository.dart';
import 'package:vivanaut/features/app_update/data/update_dismissal_store.dart';
import 'package:vivanaut/features/app_update/domain/update_policy.dart';
import 'package:vivanaut/features/app_update/presentation/app_update_gate.dart';
import 'package:vivanaut/features/app_update/presentation/app_update_providers.dart';
import 'package:vivanaut/shared/providers/external_url_launcher.dart';

const _store = 'https://play.google.com/store/apps/details?id=com.vivanaut.app';

UpdatePolicy _policy({int min = 0, int latest = 540}) => UpdatePolicy(
    minBuild: min,
    latestBuild: latest,
    latestVersion: '0.182.0',
    storeUrl: _store);

class _Repo implements AppReleasePolicyRepository {
  UpdatePolicy? next;
  int calls = 0;
  @override
  Future<UpdatePolicy?> fetch(String platform) async {
    calls++;
    return next;
  }
}

class _Dismissals implements UpdateDismissalStore {
  int? value;
  @override
  int? load() => value;
  @override
  Future<void> save(int build) async => value = build;
}

const _surface = Key('viva_modal_surface');

void main() {
  late _Repo repo;
  late _Dismissals dismissals;
  late List<Uri> launched;
  late bool launchOk;
  late GoRouter router;
  late ProviderContainer container;

  Future<void> pumpGate(WidgetTester tester) async {
    router = GoRouter(initialLocation: '/splash', routes: [
      GoRoute(
          path: '/splash',
          builder: (_, __) => const Scaffold(body: Text('splash'))),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home'))),
      GoRoute(
          path: kUpdateRequiredPath,
          builder: (_, __) => const Scaffold(body: Text('update'))),
    ]);
    addTearDown(router.dispose);
    container = ProviderContainer(overrides: [
      appReleasePolicyRepositoryProvider.overrideWithValue(repo),
      updateDismissalStoreProvider.overrideWithValue(dismissals),
      appBuildInfoProvider.overrideWith((ref) async => const AppBuildInfo(
          packageName: kUpdateTargetPackage,
          buildNumber: '530',
          platform: TargetPlatform.android)),
      externalUrlLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return launchOk;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) =>
              AppUpdateGate(router: router, child: child!),
        )));
    await tester.pumpAndSettle();
  }

  Future<void> goHome(WidgetTester tester) async {
    router.go('/home');
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _Repo();
    dismissals = _Dismissals();
    launched = [];
    launchOk = true;
  });

  testWidgets('앱이 뜨자마자(스플래시 중) 한 번 확인하고, 경로가 바뀌어도 다시 안 읽는다',
      (tester) async {
    repo.next = _policy(latest: 0);
    await pumpGate(tester);
    expect(repo.calls, 1, reason: '스플래시 중에 미리 읽어 홈 깜빡임을 없앤다');
    await goHome(tester);
    expect(repo.calls, 1);
    router.go(kUpdateRequiredPath);
    await tester.pumpAndSettle();
    expect(repo.calls, 1, reason: '경로가 바뀔 때마다 다시 읽지 않는다');
  });

  testWidgets('권장: [나중에]를 직접 누르면 그 빌드를 기억한다', (tester) async {
    repo.next = _policy();
    await pumpGate(tester);
    await goHome(tester);
    expect(find.byKey(_surface), findsOneWidget);
    expect(find.text('app_update_recommended_title'), findsOneWidget);

    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(dismissals.value, 540);
    expect(launched, isEmpty);
  });

  testWidgets('권장: 바깥 탭으로 닫히면 기억하지 않고, 이 실행에선 다시 안 띄운다', (tester) async {
    repo.next = _policy();
    await pumpGate(tester);
    await goHome(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(dismissals.value, isNull);

    router.go(kUpdateRequiredPath);
    await tester.pumpAndSettle();
    await goHome(tester);
    expect(find.byKey(_surface), findsNothing);
  });

  testWidgets('권장: [업데이트]는 스토어만 열고 기억하지 않는다', (tester) async {
    repo.next = _policy();
    await pumpGate(tester);
    await goHome(tester);
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse(_store)]);
    expect(dismissals.value, isNull);
  });

  testWidgets('권장: 스토어를 못 열면 한 줄 안내', (tester) async {
    repo.next = _policy();
    launchOk = false;
    await pumpGate(tester);
    await goHome(tester);
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('app_update_store_failed'), findsOneWidget);
  });

  testWidgets('권장 창이 떠 있는 동안 강제로 바뀌면 창을 닫고 기억하지 않는다', (tester) async {
    repo.next = _policy();
    await pumpGate(tester);
    await goHome(tester);
    expect(find.byKey(_surface), findsOneWidget);

    repo.next = _policy(min: 531, latest: 540);
    await container.read(appUpdateProvider.notifier).check();
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(dismissals.value, isNull);
    expect(launched, isEmpty);
  });

  testWidgets('[나중에]로 넘긴 빌드면 권장 창을 안 띄운다', (tester) async {
    dismissals.value = 540;
    repo.next = _policy();
    await pumpGate(tester);
    await goHome(tester);
    expect(find.byKey(_surface), findsNothing);
  });

  testWidgets('강제 상태면 복귀(resume)마다 다시 확인한다', (tester) async {
    repo.next = _policy(min: 531, latest: 540);
    await pumpGate(tester);
    await goHome(tester);
    expect(repo.calls, 1);
    await resume(tester);
    await resume(tester);
    expect(repo.calls, 3);
  });

  testWidgets('강제가 아니면 복귀 직후에는 다시 확인하지 않는다(6시간 규칙)', (tester) async {
    repo.next = _policy(latest: 0);
    await pumpGate(tester);
    await goHome(tester);
    await resume(tester);
    expect(repo.calls, 1);
  });

  testWidgets('권장 창은 스플래시 중에는 뜨지 않고, 스플래시가 끝나면 뜬다', (tester) async {
    repo.next = _policy();
    await pumpGate(tester);
    expect(repo.calls, 1);
    expect(find.byKey(_surface), findsNothing);
    await goHome(tester);
    expect(find.byKey(_surface), findsOneWidget);
  });
}
