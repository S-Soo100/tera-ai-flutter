import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../shared/domain/env_day.dart';
import '../../../shared/domain/week_range.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/env_report_repository.dart';
import '../domain/env_report.dart';
import 'home_control_providers.dart';

/// 홈 세트 기기의 [day] 일일 분석(`report_date` = 그 날짜). 화면이 보는 동안만
/// 산다(autoDispose) — 페이지를 옮기거나 다시 들어오면 새로 조회한다.
///
/// 시간으로 거르지 않는다 — 오늘 페이지에서 그리지 않는 건 화면 몫이다(계획 D11).
final envDailyReportProvider =
    StreamProvider.autoDispose.family<EnvDailyReport?, EnvDay>((ref, day) {
  final deviceId = _deviceId(ref);
  if (deviceId == null) return const Stream<EnvDailyReport?>.empty();
  final id = deviceId.id;
  if (id == null) return Stream.value(null);
  return ref.watch(envReportRepositoryProvider).watchDaily(id, day.date,
      subscribe:
          _subscribe(ref, 'env-daily-$id-${envReportDateKey(day.date)}'));
});

/// 홈 세트 기기의 [week] 주간 분석(`week_start` = 그 주 월요일).
final envWeeklyReportProvider =
    StreamProvider.autoDispose.family<EnvWeeklyReport?, WeekRange>((ref, week) {
  final deviceId = _deviceId(ref);
  if (deviceId == null) return const Stream<EnvWeeklyReport?>.empty();
  final id = deviceId.id;
  if (id == null) return Stream.value(null);
  return ref.watch(envReportRepositoryProvider).watchWeekly(id, week.monday,
      subscribe:
          _subscribe(ref, 'env-weekly-$id-${envReportDateKey(week.monday)}'));
});

/// 기기 id만 본다 — 같은 기기의 재조회(로딩↔데이터)로 채널을 다시 열지 않는다
/// (2026-09-19 재조회 깜빡임 교훈). 기기를 아직 모르면 null(로딩 유지), 계정이
/// 없으면 `(id: null)`.
({String? id})? _deviceId(Ref ref) {
  final device = ref.watch(currentDeviceIdProvider
      .select((a) => (hasValue: a.hasValue, id: a.valueOrNull)));
  if (!device.hasValue) return null;
  // 계정 id만 select-watch — 계정이 바뀌면 다시 구독한다(stale 방지).
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return (id: null);
  return (id: device.id);
}

/// 클라이언트는 실제로 구독할 때 꺼낸다(저장소가 provider build 안에서 바로
/// 부른다) — 저장소를 가짜로 바꾼 테스트는 Supabase 클라이언트가 필요 없다.
EnvReportSubscribe _subscribe(Ref ref, String name) {
  return (table, deviceId, {required onRow, required onRejoined}) {
    final supabase = ref.watch(supabaseClientProvider);
    final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'device_id',
        value: deviceId);
    final channel = bindResilientChannel(
      ref,
      supabase: supabase,
      name: name,
      configure: (c) => c
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            filter: filter,
            callback: (payload) => onRow(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            filter: filter,
            callback: (payload) => onRow(payload.newRecord),
          ),
      // 끊긴 사이 생성·갱신된 행을 놓쳤을 수 있다 — 다시 조회한다.
      onRejoined: onRejoined,
    );
    return channel.dispose;
  };
}
