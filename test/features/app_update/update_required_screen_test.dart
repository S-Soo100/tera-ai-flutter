import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/app_update/data/app_release_policy_repository.dart';
import 'package:vivanaut/features/app_update/data/update_dismissal_store.dart';
import 'package:vivanaut/features/app_update/domain/update_policy.dart';
import 'package:vivanaut/features/app_update/presentation/app_update_providers.dart';
import 'package:vivanaut/features/app_update/presentation/update_required_screen.dart';
import 'package:vivanaut/shared/providers/external_url_launcher.dart';

const _store = 'https://play.google.com/store/apps/details?id=com.vivanaut.app';

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
  @override
  int? load() => null;
  @override
  Future<void> save(int build) async {}
}

void main() {
  late _Repo repo;
  late List<Uri> launched;
  late bool launchOk;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {String version = '0.182.0'}) async {
    container = ProviderContainer(overrides: [
      appReleasePolicyRepositoryProvider.overrideWithValue(repo),
      updateDismissalStoreProvider.overrideWithValue(_Dismissals()),
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
    repo.next = UpdatePolicy(
        minBuild: 531,
        latestBuild: 540,
        latestVersion: version,
        storeUrl: _store);
    await container.read(appUpdateProvider.notifier).check();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.light, home: const UpdateRequiredScreen())));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _Repo();
    launched = [];
    launchOk = true;
  });

  testWidgets('제목·설명·버전과 버튼 둘', (tester) async {
    await pump(tester);
    expect(find.text('app_update_required_title'), findsOneWidget);
    expect(find.text('app_update_required_body'), findsOneWidget);
    expect(find.text('app_update_version'), findsOneWidget);
    expect(find.byKey(UpdateRequiredScreen.storeKey), findsOneWidget);
    expect(find.byKey(UpdateRequiredScreen.recheckKey), findsOneWidget);
    expect(find.byKey(UpdateRequiredScreen.noticeKey), findsNothing);
  });

  testWidgets('버전이 비면 버전 줄을 뺀다', (tester) async {
    await pump(tester, version: '');
    expect(find.text('app_update_version'), findsNothing);
  });

  testWidgets('[업데이트] = 스토어 열기, 실패하면 한 줄 안내', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(UpdateRequiredScreen.storeKey));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse(_store)]);
    expect(find.byKey(UpdateRequiredScreen.noticeKey), findsNothing);

    launchOk = false;
    await tester.tap(find.byKey(UpdateRequiredScreen.storeKey));
    await tester.pumpAndSettle();
    expect(find.text('app_update_store_failed'), findsOneWidget);
  });

  testWidgets('[다시 확인] = 기준을 다시 읽는다. 여전히 강제면 안내', (tester) async {
    await pump(tester);
    expect(repo.calls, 1);
    await tester.tap(find.byKey(UpdateRequiredScreen.recheckKey));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('app_update_still_required'), findsOneWidget);
  });

  testWidgets('[다시 확인]에서 풀리면 상태가 안내 없음으로(라우터가 화면을 내린다)', (tester) async {
    await pump(tester);
    repo.next = const UpdatePolicy(
        minBuild: 0, latestBuild: 0, latestVersion: '', storeUrl: _store);
    await tester.tap(find.byKey(UpdateRequiredScreen.recheckKey));
    await tester.pumpAndSettle();
    expect(container.read(appUpdateProvider).status, AppUpdateStatus.none);
    expect(find.text('app_update_still_required'), findsNothing);
  });

  testWidgets('[다시 확인]이 실패하면 강제는 그대로', (tester) async {
    await pump(tester);
    repo.next = null;
    await tester.tap(find.byKey(UpdateRequiredScreen.recheckKey));
    await tester.pumpAndSettle();
    expect(container.read(appUpdateProvider).isRequired, isTrue);
  });
}
