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
    ScheduleGuard? guard,
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
          guard: guard,
        );
    // 서버가 계산한 next_run_at을 그대로 쓴다 — 직접 계산하면 서버와 어긋난다.
    state = AsyncData([created, ...state.valueOrNull ?? const []]);
  }

  /// 구간 예약 — on(시작)·off(종료) 예약 2건 생성 (핸드오프 §1.1).
  ///
  /// 서버에 "쌍" 개념은 없다 — 목록에는 낱개 2건으로 보인다. 앱만 쌍을
  /// 기억하면 웹 콘솔·다른 기기와 어긋나므로 일부러 안 만든다.
  ///
  /// **off 생성이 실패하면 on을 지우고 다시 던진다.** on만 남으면 기기가
  /// 켜진 채 방치된다 — 히터면 과열이다. 롤백 삭제까지 실패하면 그 사실을
  /// 담아 던져 화면이 "예약 목록을 확인하라"고 말할 수 있게 한다.
  ///
  /// 가드는 **on쪽에만** 건다 — "습도가 높으면 켜지 마라"가 자연스러운 뜻이고,
  /// off는 조건 없이 꺼져야 안전하다.
  ///
  /// 시작>종료 검증은 하지 않는다 — daily 예약 2건이라 "22:00 켜고 06:00
  /// 끄기"처럼 자정을 넘는 구간이 자연스럽게 동작한다.
  Future<void> addSpan({
    required ScheduleAction onAction,
    required ScheduleAction offAction,
    required ScheduleKind kind,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required List<int> daysOfWeek,
    ScheduleGuard? guard,
  }) async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    final repo = ref.read(scheduleRepositoryProvider);
    final on = await repo.create(
      deviceId,
      action: onAction,
      kind: kind,
      hour: startHour,
      minute: startMinute,
      daysOfWeek: daysOfWeek,
      guard: guard,
    );
    final Schedule off;
    try {
      off = await repo.create(
        deviceId,
        action: offAction,
        kind: kind,
        hour: endHour,
        minute: endMinute,
        daysOfWeek: daysOfWeek,
      );
    } catch (e) {
      try {
        await repo.delete(on.id);
      } catch (_) {
        throw ScheduleException(
            0, '종료 예약 생성 실패 + 시작 예약 롤백 실패 — 예약 목록을 확인하세요: $e');
      }
      rethrow;
    }
    state = AsyncData([off, on, ...state.valueOrNull ?? const []]);
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
    ScheduleGuard? guard,
    bool clearGuard = false,
  }) async {
    final updated = await ref.read(scheduleRepositoryProvider).patch(s.id, {
      'kind': kind.wire,
      'time_of_day':
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      // daily로 바꾸면 요일을 비워야 서버가 next_run_at을 다시 계산한다.
      'days_of_week': kind == ScheduleKind.weekly ? ([...daysOfWeek]..sort()) : null,
      if (payload != null) 'payload': payload,
      // 가드 해제는 명시적 null, 유지는 키 생략 — PATCH에서 "안 바꿈"과
      // "비움"을 구분해야 한다(createBody 주석과 같은 원칙).
      if (clearGuard) 'guard': null else if (guard != null) 'guard': guard.toJson(),
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
