import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/app_update/data/app_release_policy_repository.dart';
import 'package:vivanaut/features/app_update/data/update_dismissal_store.dart';
import 'package:vivanaut/features/app_update/domain/app_update_state.dart';
import 'package:vivanaut/features/app_update/domain/update_policy.dart';
import 'package:vivanaut/features/app_update/presentation/app_update_providers.dart';

const _store = 'https://play.google.com/store/apps/details?id=com.vivanaut.app';

UpdatePolicy policy({int min = 0, int latest = 0}) => UpdatePolicy(
    minBuild: min,
    latestBuild: latest,
    latestVersion: '0.182.0',
    storeUrl: _store);

class FakePolicyRepository implements AppReleasePolicyRepository {
  UpdatePolicy? next;
  final platforms = <String>[];
  int get calls => platforms.length;
  @override
  Future<UpdatePolicy?> fetch(String platform) async {
    platforms.add(platform);
    return next;
  }
}

class FakeDismissalStore implements UpdateDismissalStore {
  int? value;
  @override
  int? load() => value;
  @override
  Future<void> save(int build) async => value = build;
}

void main() {
  late FakePolicyRepository repo;
  late FakeDismissalStore dismissals;
  late DateTime now;
  var packageName = kUpdateTargetPackage;

  AppUpdateNotifier make({String build = '530'}) => AppUpdateNotifier(
        repository: repo,
        dismissals: dismissals,
        readBuildInfo: () async => AppBuildInfo(
            packageName: packageName,
            buildNumber: build,
            platform: TargetPlatform.android),
      );

  Future<T> at<T>(Future<T> Function() body) =>
      withClock(Clock(() => now), body);

  setUp(() {
    repo = FakePolicyRepository();
    dismissals = FakeDismissalStore();
    now = DateTime(2026, 11, 16, 9);
    packageName = kUpdateTargetPackage;
  });

  test('check: 정책을 읽어 상태를 정하고 확인 시각을 남긴다', () async {
    final n = make();
    repo.next = policy(min: 531, latest: 540);
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.required);
    expect(n.state.policy?.latestBuild, 540);
    expect(n.state.lastCheckedAt, now);
    expect(repo.platforms, ['android']);
  });

  test('조회 실패(null)는 이전 상태를 유지한다 — 강제를 실패로 풀지 않는다', () async {
    final n = make();
    repo.next = policy(min: 531, latest: 540);
    await at(n.check);
    repo.next = null;
    now = now.add(const Duration(minutes: 1));
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.required);
    expect(n.state.lastCheckedAt, DateTime(2026, 11, 16, 9),
        reason: '실패는 성공 확인 시각을 바꾸지 않는다');
  });

  test('처음부터 조회 실패면 안내 없음', () async {
    final n = make();
    repo.next = null;
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.none);
    expect(n.state.lastCheckedAt, isNull);
  });

  test('운영자가 값을 되돌리면 다시 확인에서 강제가 풀린다', () async {
    final n = make();
    repo.next = policy(min: 531, latest: 540);
    await at(n.check);
    repo.next = policy();
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.none);
  });

  group('복귀(resume) 재확인 규칙 §1-D', () {
    test('강제 상태면 복귀마다 확인한다', () async {
      final n = make();
      repo.next = policy(min: 531, latest: 540);
      await at(n.check);
      expect(repo.calls, 1);
      now = now.add(const Duration(seconds: 5));
      await at(n.checkOnResume);
      now = now.add(const Duration(seconds: 5));
      await at(n.checkOnResume);
      expect(repo.calls, 3);
    });

    test('강제가 아니면 마지막 성공 확인에서 6시간이 지나야 확인한다', () async {
      final n = make();
      repo.next = policy(latest: 540);
      await at(n.check);
      expect(repo.calls, 1);
      now = now.add(const Duration(hours: 5, minutes: 59));
      await at(n.checkOnResume);
      expect(repo.calls, 1);
      now = now.add(const Duration(minutes: 1));
      await at(n.checkOnResume);
      expect(repo.calls, 2);
    });

    test('성공한 적이 없으면(오프라인 시작) 복귀 때 확인한다', () async {
      final n = make();
      repo.next = null;
      await at(n.check);
      await at(n.checkOnResume);
      expect(repo.calls, 2);
    });

    test('6시간 뒤 확인이 실패하면 다음 복귀에도 다시 확인한다', () async {
      final n = make();
      repo.next = policy();
      await at(n.check);
      now = now.add(const Duration(hours: 7));
      repo.next = null;
      await at(n.checkOnResume);
      await at(n.checkOnResume);
      expect(repo.calls, 3);
    });
  });

  test('동시에 부르면 조회는 한 번', () async {
    final gate = Completer<UpdatePolicy?>();
    final slow = _SlowRepository(gate.future);
    final n = AppUpdateNotifier(
        repository: slow,
        dismissals: dismissals,
        readBuildInfo: () async => const AppBuildInfo(
            packageName: kUpdateTargetPackage,
            buildNumber: '530',
            platform: TargetPlatform.android));
    final a = at(n.check);
    final b = at(n.check);
    gate.complete(policy(latest: 540));
    await Future.wait([a, b]);
    expect(slow.calls, 1);
    expect(n.state.status, AppUpdateStatus.recommended);
  });

  test('[나중에] 기록 → 같은 latest에는 권장이 다시 안 뜬다', () async {
    final n = make();
    repo.next = policy(latest: 540);
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.recommended);
    await n.dismissRecommended();
    expect(dismissals.value, 540);
    expect(n.state.status, AppUpdateStatus.none);
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.none);
  });

  test('강제 상태에서는 [나중에]가 아무것도 바꾸지 않는다', () async {
    final n = make();
    repo.next = policy(min: 531, latest: 540);
    await at(n.check);
    await n.dismissRecommended();
    expect(dismissals.value, isNull);
    expect(n.state.status, AppUpdateStatus.required);
  });

  test('베타 번들은 조회하지 않는다', () async {
    packageName = 'com.vivanaut.beta';
    final n = make();
    repo.next = policy(min: 9999, latest: 9999);
    await at(n.check);
    expect(repo.calls, 0);
    expect(n.state.status, AppUpdateStatus.none);
  });

  test('빌드 정보를 못 읽으면 안내 없음(던지지 않는다)', () async {
    final n = AppUpdateNotifier(
        repository: repo,
        dismissals: dismissals,
        readBuildInfo: () async => throw StateError('no package info'));
    repo.next = policy(min: 9999, latest: 9999);
    await at(n.check);
    expect(n.state.status, AppUpdateStatus.none);
  });

  test('AppUpdateState 기본값은 안내 없음', () {
    expect(const AppUpdateState().status, AppUpdateStatus.none);
  });
}

class _SlowRepository implements AppReleasePolicyRepository {
  _SlowRepository(this.result);
  final Future<UpdatePolicy?> result;
  int calls = 0;
  @override
  Future<UpdatePolicy?> fetch(String platform) {
    calls++;
    return result;
  }
}
