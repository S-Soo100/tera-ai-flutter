import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/control_log.dart';
import 'package:vivanaut/shared/domain/fan_actuator.dart';
import 'package:vivanaut/shared/domain/fan_timer_notification_plan.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 0, 10);
  Map<String, dynamic> command(String action,
          {String? result = 'ok', int minute = 0}) =>
      {
        'id': '$action-$minute',
        'device_id': 'd1',
        'action': action,
        'status': 'acked',
        'result': result,
        'issued_at': DateTime.utc(2026, 9, 15, 0, minute).toIso8601String(),
        'payload': {'duration_ms': 1800000},
      };

  test('미보고 fan2를 꺼짐으로 만들지 않고 실제 on/off를 읽는다', () {
    expect(TelemetryReading.fromJson({}).fan2, ActuatorState.unavailable);
    expect(TelemetryReading.fromJson({'fan2': null}).fan2,
        ActuatorState.unavailable);
    expect(TelemetryReading.fromJson({'fan2': true}).fan2, ActuatorState.on);
    expect(TelemetryReading.fromJson({'fan2': false}).fan2, ActuatorState.off);
  });

  test('한 팬의 OFF는 다른 팬의 타이머를 취소하지 않는다', () {
    final rows = [
      command('fan_off', minute: 9),
      command('fan2_on', minute: 1),
      command('fan_on')
    ];
    expect(RunningTimer.fanTimerFrom(rows, now), isNull);
    final cooling =
        RunningTimer.fanTimerFrom(rows, now, actuator: FanActuator.cooling)!;
    expect(cooling.actuatorLabelKey, 'device_cool_fan');
    expect(cooling.remaining(now), const Duration(minutes: 21));
  });

  for (final result in ['busy', 'error', 'unknown_action', null]) {
    test('acked/$result는 성공 기록도 아니고 이전 타이머를 끄지도 않는다', () {
      final failed = command('fan2_off', result: result, minute: 9);
      expect(ActuatorMarker.fromCommands([failed]), isEmpty);
      expect(buildControlLog(commandRows: [failed], buckets: []), isEmpty);
      expect(
          RunningTimer.fanTimerFrom([failed, command('fan2_on')], now,
                  actuator: FanActuator.cooling)
              ?.remaining(now),
          const Duration(minutes: 20));
      expect(
          RunningTimer.fanTimerFrom([command('fan2_on', result: result)], now,
              actuator: FanActuator.cooling),
          isNull);
    });
  }

  test('팬별 기억값 키와 알림 ID를 분리하고 기존 환기팬 키는 유지한다', () {
    expect(FanActuator.ventilation.storageKey('d1'), 'd1');
    expect(FanActuator.cooling.storageKey('d1'), isNot('d1'));
    expect(notificationIdFor('d1', actuator: FanActuator.cooling),
        isNot(notificationIdFor('d1')));
    final start =
        FanTimerNotificationPlan.of('fan2_on', 600000) as ScheduleFanDone;
    expect(start.actuator, FanActuator.cooling);
    expect(start.minutes, 10);
    expect(
        (FanTimerNotificationPlan.of('fan2_off', null) as CancelFanDone)
            .actuator,
        FanActuator.cooling);
  });
  test('냉각팬 명령은 unknown으로 소실되지 않고 wire를 보존한다', () {
    for (final wire in ['fan2_on', 'fan2_off', 'fan2_toggle']) {
      expect(CommandActionWire.fromWire(wire).toWire(), wire);
    }
    final off = ScheduleAction.fromWire('fan2_off');
    expect(off.isOffAction, true);
    expect(off.onCounterpart?.wire, 'fan2_on');
    expect(ScheduleAction.selectable.map((a) => a.wire),
        containsAll(['fan2_on', 'fan2_off']));
    expect(ScheduleAction.selectable.map((a) => a.wire),
        isNot(contains('fan2_toggle')));
  });

  test('냉각팬의 기록과 마커를 환기팬과 다른 종류로 보존한다', () {
    final rows = [
      {
        'action': 'fan_on',
        'status': 'acked',
        'result': 'ok',
        'issued_at': '2026-09-15T00:00:00Z'
      },
      {
        'action': 'fan2_on',
        'status': 'acked',
        'result': 'ok',
        'issued_at': '2026-09-15T00:01:00Z'
      },
      {
        'action': 'fan2_off',
        'status': 'acked',
        'result': 'ok',
        'issued_at': '2026-09-15T00:02:00Z'
      },
    ];
    final markers = ActuatorMarker.fromCommands(rows);
    expect(markers, hasLength(3));
    expect(markers[1].kind, isNot(markers[0].kind));
    final logs = buildControlLog(commandRows: rows, buckets: []);
    expect(logs, hasLength(3));
    expect(logs[2].kind, logs[1].kind);
    expect(logs[2].kind, isNot(logs[0].kind));
  });
}
