import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../shared/domain/fan_actuator.dart';
import '../../domain/running_timer.dart';
import '../home_control_providers.dart';

// 이 파일에는 진행 중 팬 타이머 provider만 남아 있다. 홈 상단 타이머 칩
// 위젯(`RunningTimerChip`)은 2026-09-16부터 화면에서 쓰지 않아 2026-11-21에
// 지웠다 — 진행 표시는 제어 타일 부제의 카운트다운이다. 파일 이름은 import
// 경로를 유지하려고 그대로 둔다.

// 1초 tick은 라이브 쉼 카운트다운도 써서 shared로 옮겼다(2026-09-30). 기존
// import 경로를 그대로 두려고 다시 내보낸다.
export '../../../../shared/providers/clock_providers.dart'
    show secondTickProvider;

/// 타이머가 떠 있는 동안의 재검증 주기 ([runningTimersProvider]).
const _kTimerRevalidateEvery = Duration(seconds: 30);

/// 현재 세트 제어기의 진행 중 팬 타이머 (A안 — `commands`에서 계산).
///
/// `issued_at + duration_ms`로 종료 시각을 만든다(2026-08-14 핸드오프 §1.3).
/// 서버에 타이머 상태를 따로 두지 않아 다기기에서 같은 값이 나온다.
/// 타이머 발행·취소 직후에는 발행부(`cage_control_actions.dart`)가 이 provider를
/// invalidate해 칩을 깨운다.
///
/// **타이머가 보이는 동안엔 30초마다 스스로 재검증한다.** 취소는 홈 밖에서도
/// 온다(사육장 탭 fan_off·예약·웹 콘솔). pending 발행이 TTL(10초)로 `expired`가
/// 될 수도 있다(기기 오프라인 — 팬은 켜진 적이 없다). 이 provider에는 Realtime
/// 구독이 없어 재조회 없이는 그 어떤 것도 반영되지 않고, 유령 카운트다운이
/// 최대 2시간 남는다. 만료 시각에도 한 번 깨워 칩(과 1초 tick 구독)을 내린다.
///
/// 조회 실패는 빈 목록으로 흡수한다 — 칩 하나 때문에 제어 탭 전체를 에러
/// 화면으로 만들지 않는다.
final runningTimersProvider =
    FutureProvider.autoDispose<List<RunningTimer>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  var alive = true;
  ref.onDispose(() => alive = false);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  try {
    final timers = <RunningTimer>[];
    final now = DateTime.now();
    for (final actuator in FanActuator.values) {
      final rows = await client
          .from('commands')
          .select(kFanTimerColumns)
          .eq('device_id', deviceId)
          .inFilter('action', actuator.actions)
          .order('issued_at', ascending: false)
          .limit(10);
      final t = RunningTimer.fanTimerFrom(
        (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        now,
        actuator: actuator,
      );
      if (t != null) timers.add(t);
    }
    if (!alive) return const [];
    if (timers.isNotEmpty) {
      final remaining =
          timers.map((t) => t.remaining(now)).reduce((a, b) => a < b ? a : b);
      final refreshIn = remaining < _kTimerRevalidateEvery
          ? remaining + const Duration(seconds: 1)
          : _kTimerRevalidateEvery;
      final timer = Timer(refreshIn, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
    return timers;
  } catch (_) {
    return const [];
  }
});
