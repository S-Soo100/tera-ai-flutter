import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/terra_rest_client.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule.dart';
import 'home_control_providers.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(terraRestClientProvider));
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

  /// 구간 예약 — on(시작)·off(종료) 예약 2건을 **같은 `pair_id`**로 생성
  /// (2026-08-18 회신 §3). 서버가 짝을 묶어 목록에서 한 줄로 그리고, 삭제는
  /// 한 건만 지워도 짝이 같이 지워진다.
  ///
  /// **off 생성이 실패하면 on을 지우고 다시 던진다.** on만 남으면 기기가
  /// 켜진 채 방치된다 — 히터면 과열이다. 롤백 삭제까지 실패하면 그 사실을
  /// 담아 던져 화면이 "예약 목록을 확인하라"고 말할 수 있게 한다.
  ///
  /// 가드는 **on쪽에만** 건다 — "습도가 높으면 켜지 마라"가 자연스러운 뜻이고,
  /// off는 조건 없이 꺼져야 안전하다(서버도 off+guard를 400으로 막는다, §4-3).
  ///
  /// 시작>종료 검증은 하지 않는다 — 자정을 넘는 구간("22:00 켜고 06:00 끄기")은
  /// 정상 사용이다. 대신 **weekly + 자정 넘김이면 off쪽 요일을 하루 민다**
  /// ([Schedule.offLegDays]) — 안 밀면 off가 그 주의 on보다 먼저 발화해
  /// 켜진 기기가 다음 주까지 안 꺼진다.
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
    final pairId = const Uuid().v4();
    final on = await repo.create(
      deviceId,
      action: onAction,
      kind: kind,
      hour: startHour,
      minute: startMinute,
      daysOfWeek: daysOfWeek,
      guard: guard,
      pairId: pairId,
    );
    final offDays = Schedule.offLegDays(
      kind: kind,
      daysOfWeek: daysOfWeek,
      crossesMidnight: Schedule.spanCrossesMidnight(
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      ),
    );
    final Schedule off;
    try {
      off = await repo.create(
        deviceId,
        action: offAction,
        kind: kind,
        hour: endHour,
        minute: endMinute,
        daysOfWeek: offDays,
        pairId: pairId,
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

  /// 구간 한 줄 ON/OFF — 두 행을 같이 바꾼다. on을 먼저 바꾸고 off가 실패하면
  /// on을 **원래 값**으로 되돌린다: on만 켜진 채 남는 쪽이 위험하다(꺼지지 않는
  /// 히터). 되돌리기까지 실패하면 그 사실을 담아 던진다 — 원래 에러를 삼키고
  /// "실패했다"만 말하면 사용자는 목록이 서버와 어긋난 줄 모른다.
  Future<void> setPairEnabled(SchedulePair p, bool enabled) async {
    final repo = ref.read(scheduleRepositoryProvider);
    final prevOn = p.on.enabled;
    final on = await repo.patch(p.on.id, {'enabled': enabled});
    _replace(on);
    try {
      final off = await repo.patch(p.off.id, {'enabled': enabled});
      _replace(off);
    } catch (e) {
      try {
        _replace(await repo.patch(p.on.id, {'enabled': prevOn}));
      } catch (_) {
        throw ScheduleException(
            0, '종료 예약 변경 실패 + 시작 예약 복구 실패 — 예약 목록을 확인하세요: $e');
      }
      rethrow;
    }
  }

  /// 구간 삭제 — 서버가 짝을 함께 지운다(회신 §3)고 **믿지 않고 다시 읽는다.**
  /// 한 건만 DELETE한 뒤 목록을 재조회해 서버가 실제로 남긴 것을 그린다 —
  /// 캐스케이드가 없는 서버(구버전)라면 off 낱개가 그대로 보여 지울 수 있다.
  Future<void> removePair(SchedulePair p) async {
    final deviceId = _deviceId;
    final repo = ref.read(scheduleRepositoryProvider);
    await repo.delete(p.on.id);
    if (deviceId == null) return;
    state = AsyncData(await repo.list(deviceId));
  }

  /// 구간 타이밍 수정 — on을 먼저 PATCH하고 off를 PATCH한다. off는 요일 밀기를
  /// 다시 계산하고, 가드는 on쪽에만 싣는다(off+guard는 서버 400).
  ///
  /// **off가 실패하면 on을 원래 타이밍으로 되돌린다.** 안 되돌리면 새 시각에
  /// 켜지고 옛 시각에 꺼지는 반쪽 구간이 남는다 — 히터면 꺼지기 전에 켜지는
  /// 순서로 뒤집힐 수 있다([addSpan]의 롤백과 같은 불변식).
  Future<void> updateSpanTiming(
    SchedulePair p, {
    required ScheduleKind kind,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required List<int> daysOfWeek,
    ScheduleGuard? guard,
    bool clearGuard = false,
  }) async {
    final origOn = p.on;
    await updateTiming(
      p.on,
      kind: kind,
      hour: startHour,
      minute: startMinute,
      daysOfWeek: daysOfWeek,
      guard: guard,
      clearGuard: clearGuard,
    );
    final offDays = Schedule.offLegDays(
      kind: kind,
      daysOfWeek: daysOfWeek,
      crossesMidnight: Schedule.spanCrossesMidnight(
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      ),
    );
    try {
      await updateTiming(
        p.off,
        kind: kind,
        hour: endHour,
        minute: endMinute,
        daysOfWeek: offDays,
      );
    } catch (e) {
      try {
        await updateTiming(
          origOn,
          kind: origOn.kind,
          hour: origOn.hour,
          minute: origOn.minute,
          daysOfWeek: origOn.daysOfWeek,
          // 원래 가드가 있었으면 그대로, 없었으면 명시적으로 비운다.
          guard: origOn.guard,
          clearGuard: origOn.guard == null,
        );
      } catch (_) {
        throw ScheduleException(
            0, '종료 예약 수정 실패 + 시작 예약 복구 실패 — 예약 목록을 확인하세요: $e');
      }
      rethrow;
    }
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

  /// PATCH 응답의 `pair_id`가 비어 있으면 기존 값을 지킨다 — 회신 §3은 GET/POST
  /// 응답만 명시했다. 응답이 바뀐 컬럼만 돌려주는 순간 구간 한 줄이 낱개 둘로
  /// 쪼개지는 걸 막는다.
  void _replace(Schedule updated) {
    state = AsyncData([
      for (final e in state.valueOrNull ?? const <Schedule>[])
        if (e.id == updated.id)
          (updated.pairId == null && e.pairId != null
              ? updated.copyWith(pairId: e.pairId)
              : updated)
        else
          e,
    ]);
  }
}
