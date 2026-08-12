import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule.dart';
import 'home_control_providers.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(
    baseUrl: EnvConfig.terraServerUrl,
    tokenProvider: () async =>
        Supabase.instance.client.auth.currentSession?.accessToken,
    supabase: Supabase.instance.client,
  );
});

/// 현재 사육장의 예약 목록.
///
/// autoDispose다 — 설정 화면을 벗어나면 버린다. 들어올 때마다 서버에서 다시
/// 읽어야 다른 기기에서 바꾼 예약이 반영된다.
final schedulesProvider =
    AsyncNotifierProvider.autoDispose<SchedulesNotifier, List<Schedule>>(
  SchedulesNotifier.new,
);

class SchedulesNotifier extends AutoDisposeAsyncNotifier<List<Schedule>> {
  String? _deviceId;

  @override
  Future<List<Schedule>> build() async {
    final deviceId = await ref.watch(currentDeviceIdProvider.future);
    _deviceId = deviceId;
    if (deviceId == null) return const [];
    return ref.watch(scheduleRepositoryProvider).list(deviceId);
  }

  Future<void> add({
    required ScheduleAction action,
    required ScheduleKind kind,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    Map<String, dynamic>? payload,
  }) async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    final created = await ref.read(scheduleRepositoryProvider).create(
          deviceId,
          action: action,
          kind: kind,
          hour: hour,
          minute: minute,
          daysOfWeek: daysOfWeek,
          payload: payload,
        );
    // 서버가 계산한 next_run_at을 그대로 쓴다 — 직접 계산하면 서버와 어긋난다.
    state = AsyncData([created, ...state.valueOrNull ?? const []]);
  }

  /// 일정 ON/OFF. 목록에서 토글로 바로 누른다.
  ///
  /// **낙관적 업데이트는 하지 않는다.** 실패했는데 켜진 것처럼 보이면
  /// 사용자는 예약이 도는 줄 알고 기다린다 — 사육 기기에서 이건 위험한 거짓말이다.
  Future<void> setEnabled(Schedule s, bool enabled) async {
    final updated = await ref
        .read(scheduleRepositoryProvider)
        .patch(s.id, {'enabled': enabled});
    _replace(updated);
  }

  Future<void> remove(Schedule s) async {
    await ref.read(scheduleRepositoryProvider).delete(s.id);
    state = AsyncData(
      [...?state.valueOrNull].where((e) => e.id != s.id).toList(),
    );
  }

  Future<void> updateTiming(
    Schedule s, {
    required ScheduleKind kind,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    Map<String, dynamic>? payload,
  }) async {
    final updated = await ref.read(scheduleRepositoryProvider).patch(s.id, {
      'kind': kind.wire,
      'time_of_day':
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      // daily로 바꾸면 요일을 비워야 서버가 next_run_at을 다시 계산한다.
      'days_of_week': kind == ScheduleKind.weekly ? ([...daysOfWeek]..sort()) : null,
      if (payload != null) 'payload': payload,
    });
    _replace(updated);
  }

  void _replace(Schedule updated) {
    state = AsyncData([
      for (final e in state.valueOrNull ?? const <Schedule>[])
        if (e.id == updated.id) updated else e,
    ]);
  }
}
