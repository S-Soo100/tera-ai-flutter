import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/my_cage/data/supabase_module_control_repository.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/shared/domain/env_day.dart';

/// 오늘 화면은 마감 전 30분 칸까지 읽고(원본 꼬리), 1분마다 다시 읽는다
/// (2026-11-04 — 오늘 최고 25인데 현재 26.9·알림 27.7이던 사고).
class _Repo implements SupabaseModuleControlRepository {
  final calls = <String>[];

  @override
  Future<List<TelemetryBucket>> telemetryHistory(String deviceId, DateTime from,
      {DateTime? to}) async {
    calls.add('closed');
    return const [];
  }

  @override
  Future<List<TelemetryBucket>> telemetryHistoryWithTail(
      String deviceId, DateTime from,
      {DateTime? to}) async {
    calls.add('tail');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _Repo repo;
  late StreamController<DateTime> ticks;
  late ProviderContainer container;

  setUp(() {
    repo = _Repo();
    ticks = StreamController<DateTime>();
    container = ProviderContainer(overrides: [
      supabaseModuleControlRepositoryProvider.overrideWithValue(repo),
      currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
      envDetailNowProvider.overrideWith((ref) => ticks.stream),
    ]);
  });
  tearDown(() {
    container.dispose();
    ticks.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('오늘은 원본 꼬리까지 읽고, 1분 틱마다 다시 읽는다', () async {
    final sub = container.listen(envDayBucketsProvider, (_, __) {});
    addTearDown(sub.close);
    ticks.add(DateTime.now());
    await container.read(envDayBucketsProvider.future);
    expect(repo.calls, ['tail']);

    ticks.add(DateTime.now().add(const Duration(minutes: 1)));
    await settle();
    await container.read(envDayBucketsProvider.future);
    expect(repo.calls, ['tail', 'tail']);
  });

  test('지난 날은 마감 칸만 읽고 틱에 다시 읽지 않는다', () async {
    container.read(envDetailDayProvider.notifier).state =
        EnvDay.of(DateTime.now()).previous;
    final sub = container.listen(envDayBucketsProvider, (_, __) {});
    addTearDown(sub.close);
    ticks.add(DateTime.now());
    await container.read(envDayBucketsProvider.future);
    ticks.add(DateTime.now().add(const Duration(minutes: 1)));
    await settle();
    await container.read(envDayBucketsProvider.future);
    expect(repo.calls, ['closed']);
  });

  test('홈 오늘 최고·최저도 원본 꼬리까지 읽는다', () async {
    final sub = container.listen(homeTodayExtremesProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(homeTodayExtremesProvider.future);
    expect(repo.calls, ['tail']);
  });
}
