// v4 일일·주간 분석 provider(계획 2026-11-03 Task 3) — 진짜 provider + 가짜 저장소.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_report_repository.dart';
import 'package:vivanaut/features/home/presentation/env_report_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/shared/domain/env_day.dart';
import 'package:vivanaut/shared/domain/week_range.dart';

import 'env_v4_screen_fixtures.dart';

User _user() => User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01');

final _device = StateProvider<String?>((ref) => 'd1');

void main() {
  final day = EnvDay(DateTime(2026, 11, 2));
  final week = WeekRange(DateTime(2026, 10, 26));

  ProviderContainer container(FakeEnvReportRepository repo,
      {User? user, bool deviceKnown = true}) {
    final c = ProviderContainer(overrides: [
      envReportRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => user),
      currentDeviceIdProvider.overrideWith((ref) => deviceKnown
          ? Future.value(ref.watch(_device))
          : Completer<String?>().future),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('기기·날짜로 조회한다, 기기를 바꾸면 새 기기로 다시', () async {
    final repo = FakeEnvReportRepository();
    final c = container(repo, user: _user());
    final sub = c.listen(envDailyReportProvider(day), (_, __) {});
    await c.read(envDailyReportProvider(day).future);
    expect(repo.dailyCalls, ['d1@2026-11-02']);
    c.read(_device.notifier).state = 'd2';
    await c.read(currentDeviceIdProvider.future);
    await Future<void>.delayed(Duration.zero);
    await c.read(envDailyReportProvider(day).future);
    expect(repo.dailyCalls, ['d1@2026-11-02', 'd2@2026-11-02']);
    sub.close();
  });

  test('주간은 그 주 월요일로 조회', () async {
    final repo = FakeEnvReportRepository();
    final c = container(repo, user: _user());
    final sub = c.listen(envWeeklyReportProvider(week), (_, __) {});
    await c.read(envWeeklyReportProvider(week).future);
    expect(repo.weeklyCalls, ['d1@2026-10-26']);
    sub.close();
  });

  test('계정이 없으면 null, 조회 0회', () async {
    final repo = FakeEnvReportRepository();
    final c = container(repo);
    final sub = c.listen(envDailyReportProvider(day), (_, __) {});
    expect(await c.read(envDailyReportProvider(day).future), isNull);
    expect(repo.dailyCalls, isEmpty);
    sub.close();
  });

  test('기기를 아직 모르면 로딩 유지, 조회 0회', () async {
    final repo = FakeEnvReportRepository();
    final c = container(repo, user: _user(), deviceKnown: false);
    final sub = c.listen(envDailyReportProvider(day), (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(envDailyReportProvider(day)).isLoading, isTrue);
    expect(repo.dailyCalls, isEmpty);
    sub.close();
  });
}
