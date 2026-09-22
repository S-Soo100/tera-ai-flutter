/// 제어 명령 확인 대기 — 누른 뒤 기기가 실제로 반영할 때까지.
///
/// 스위치가 텔레메트리만 따라가면 누르고 2~3초(실측 반영 p50 1.7s·p90 3s,
/// 2026-09-22) 동안 원래 자리에 머문다. 사용자는 안 눌린 줄 알고 다시 누르고,
/// 기기는 연타를 `busy`로 거절한다(실측 fan_on 22%). 그래서 누르는 즉시
/// 목표 상태를 로딩으로 보여 주고, 확인될 때까지 **그 사육장의 제어 전체를
/// 잠근다**(2026-09-22 사용자 결정). 끝나는 조건:
/// - 기기 텔레메트리가 목표 상태를 보고 → 성공
/// - 명령이 거절(`busy`/`error`/`rejected`)·미전달(`no_ack`/`expired`/`lost`) → 즉시 실패 안내
/// - [kControlConfirmPolls]초 안에 둘 다 없음 → ACK 성공이었으면 조용히 해제, 아니면 무응답 안내
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../my_cage/domain/actuator_state.dart';
import '../../my_cage/domain/device_command.dart';
import '../../my_cage/domain/telemetry_reading.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../domain/schedule_device.dart';

/// 확인을 기다리는 최대 횟수(1초 간격) — 실측 반영 최대 5.8초에 여유.
const kControlConfirmPolls = 8;
const kControlPollInterval = Duration(seconds: 1);

/// 확인 대기 중인 제어 한 건.
@immutable
class ControlPending {
  const ControlPending(this.device, this.expectOn);
  final ScheduleDevice device;

  /// 기기가 보고해야 할 상태. null이면 상태가 바뀌지 않는 명령(켜진 채 타이머
  /// 교체·밝기 변경·분무) — ACK로만 확인한다.
  final bool? expectOn;
}

/// 명령 처리 결과.
enum ControlOutcome { ok, busy, rejected, noResponse }

/// `commands` 행의 status/result → 확정 결과. 아직 모르면 null.
ControlOutcome? classifyCommand(String? status, String? result) =>
    switch (status) {
      'acked' => switch (result) {
          'ok' => ControlOutcome.ok,
          'busy' => ControlOutcome.busy,
          _ => ControlOutcome.rejected,
        },
      'rejected' => ControlOutcome.rejected,
      'no_ack' || 'expired' || 'lost' => ControlOutcome.noResponse,
      _ => null, // pending / sent
    };

/// 실패 안내 문구 키. 성공은 null.
String? controlOutcomeMessageKey(ControlOutcome o) => switch (o) {
      ControlOutcome.ok => null,
      ControlOutcome.busy => 'module_command_busy',
      ControlOutcome.rejected => 'module_command_rejected',
      ControlOutcome.noResponse => 'module_command_no_ack',
    };

typedef CommandStatusFetcher = Future<({String? status, String? result})?>
    Function(String commandId);

/// 명령 상태 1회 조회. 테스트가 바꿔 끼운다.
final commandStatusFetcherProvider = Provider<CommandStatusFetcher>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (id) async {
    final row = await client
        .from('commands')
        .select('status, result')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return (status: row['status'] as String?, result: row['result'] as String?);
  };
});

ActuatorState? actuatorStateOf(TelemetryReading? t, ScheduleDevice device) =>
    switch (device) {
      ScheduleDevice.fan => t?.fan,
      ScheduleDevice.cool => t?.fan2,
      ScheduleDevice.led => t?.led,
      ScheduleDevice.heater => t?.heaterState,
      ScheduleDevice.mist => null,
    };

/// 사육장(기기 id)별 확인 대기. null이면 대기 없음.
///
/// 시트가 닫혀도 확인은 계속된다 — 홈 타일이 같은 상태를 그린다.
final controlPendingProvider =
    NotifierProvider.family<ControlPendingNotifier, ControlPending?, String>(
        ControlPendingNotifier.new);

class ControlPendingNotifier extends FamilyNotifier<ControlPending?, String> {
  @override
  ControlPending? build(String arg) => null;

  /// 기기가 목표 상태를 보고했는지 — [begin]부터 듣는다. 전송 응답보다 기기
  /// 보고가 먼저 올 수 있어서다(전송 await 뒤에 구독하면 그 보고를 놓친다).
  Completer<void>? _reported;
  ProviderSubscription<AsyncValue<TelemetryReading?>>? _sub;

  /// 대기를 시작한다. 이미 대기 중이면 false — 호출부는 보내지 않는다.
  bool begin(ScheduleDevice device, bool? expectOn) {
    if (state != null) return false;
    state = ControlPending(device, expectOn);
    if (expectOn != null) {
      final reported = _reported = Completer<void>();
      final want = expectOn ? ActuatorState.on : ActuatorState.off;
      _sub = ref.listen(telemetryStreamProvider(arg), (_, next) {
        if (!reported.isCompleted &&
            actuatorStateOf(next.valueOrNull, device) == want) {
          reported.complete();
        }
      });
    }
    return true;
  }

  /// 전송 실패 등으로 확인 없이 끝낸다.
  void cancel() => _end();

  void _end() {
    _sub?.close();
    _sub = null;
    _reported = null;
    state = null;
  }

  /// [command]가 확인될 때까지 기다린 뒤 대기를 푼다.
  Future<ControlOutcome> confirm(DeviceCommand command) async {
    final expectOn = state?.expectOn;
    final done = Completer<ControlOutcome>();
    void finish(ControlOutcome o) {
      if (!done.isCompleted) done.complete(o);
    }

    _reported?.future.then((_) => finish(ControlOutcome.ok));
    final fetch = ref.read(commandStatusFetcherProvider);
    var acked = false;
    for (var i = 0; i < kControlConfirmPolls && !done.isCompleted; i++) {
      await Future.any(
          [done.future, Future<void>.delayed(kControlPollInterval)]);
      if (done.isCompleted) break;
      try {
        final s = await fetch(command.id);
        final outcome = classifyCommand(s?.status, s?.result);
        if (outcome == ControlOutcome.ok) {
          acked = true;
          // 상태가 안 바뀌는 명령은 ACK가 곧 확인이다.
          if (expectOn == null) finish(ControlOutcome.ok);
        } else if (outcome != null) {
          finish(outcome);
        }
      } catch (_) {
        // 조회 실패는 유실 확정이 아니다 — 다음 회차에 다시 본다.
      }
    }
    // ACK는 됐는데 반영 보고가 늦은 경우는 실패로 겁주지 않는다.
    finish(acked ? ControlOutcome.ok : ControlOutcome.noResponse);
    _end();
    return done.future;
  }
}

/// 확인 결과를 스낵바로 알린다(성공은 조용히).
void showControlOutcome(ScaffoldMessengerState messenger, ControlOutcome o) {
  final key = controlOutcomeMessageKey(o);
  if (key == null || !messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(key.tr())));
}
