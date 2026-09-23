// 제어 확인 대기(2026-09-22) — 누르면 즉시 목표 상태 + 로딩, 확인 전엔 그
// 사육장의 제어 전체 잠금, 거절·무응답은 바로 알리고 원래 상태로 돌아간다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/mist_duration.dart';
import 'package:vivanaut/features/home/domain/mist_lock.dart';
import 'package:vivanaut/features/home/presentation/cage_control_actions.dart';
import 'package:vivanaut/features/home/domain/schedule_device.dart';
import 'package:vivanaut/features/home/presentation/control_pending.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/home/presentation/widgets/cage_control_grid.dart';
import 'package:vivanaut/features/home/presentation/widgets/device_control_sheet.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'control_sheet_fixtures.dart';

typedef _Status = ({String? status, String? result});

Future<
    (
      List<(CommandAction, Map<String, dynamic>?)>,
      StreamController<TelemetryReading?>
    )> _pump(WidgetTester tester, _Status status,
        {ScheduleDevice device = ScheduleDevice.fan,
        ActuatorState led = ActuatorState.unavailable}) async {
  final sent = <(CommandAction, Map<String, dynamic>?)>[];
  // 현재 상태(꺼짐)부터 준다 — 실제 스트림의 seed와 같다.
  final telemetry = StreamController<TelemetryReading?>()
    ..add(reading(fan2: ActuatorState.off, led: led));
  await tester.pumpWidget(controlApp(
      Column(children: [
        const CageControlGrid(),
        Expanded(
            child: Align(
                alignment: Alignment.bottomCenter,
                child: DeviceControlSheet(
                    deviceId: kTestDeviceId, device: device))),
      ]),
      controlOverrides(
          sent: sent,
          telemetryStream: telemetry.stream,
          statusFetcher: (_) async => status)));
  await tester.pumpAndSettle();
  return (sent, telemetry);
}

bool _switchOn(WidgetTester tester) => tester
    .widget<ScheduleSwitch>(find.byKey(DeviceControlSheet.powerSwitchKey))
    .value;

VoidCallback? _tileTap(WidgetTester tester, Key key) => tester
    .widget<InkWell>(
        find.descendant(of: find.byKey(key), matching: find.byType(InkWell)))
    .onTap;

void main() {
  testWidgets('켜기 — 즉시 켜짐+로딩, 확인 전엔 전부 잠금, 기기 보고 오면 해제',
      (tester) async {
    final (sent, telemetry) =
        await _pump(tester, (status: 'sent', result: null));
    expect(_switchOn(tester), isFalse);

    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.single.$1, CommandAction.fanOn);
    // 기기 보고 전인데도 스위치는 켜짐 쪽에 있고, 행과 타일에 로딩이 흐른다.
    expect(_switchOn(tester), isTrue);
    expect(find.byKey(DeviceControlSheet.loadingKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.loadingKey), findsOneWidget);
    // 다른 장치 타일도 잠긴다.
    expect(_tileTap(tester, CageControlGrid.coolFanKey), isNull);
    expect(_tileTap(tester, CageControlGrid.mistKey), isNull);
    // 연타는 나가지 않는다.
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent, hasLength(1));

    telemetry.add(reading(fan: ActuatorState.on, fan2: ActuatorState.off));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(DeviceControlSheet.loadingKey), findsNothing);
    expect(find.byKey(CageControlGrid.loadingKey), findsNothing);
    expect(_switchOn(tester), isTrue);
    expect(_tileTap(tester, CageControlGrid.coolFanKey), isNotNull);
    expect(find.text('module_command_no_ack'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('기기가 busy로 거절 — 1초 조회에서 바로 안내, 스위치 원위치, 잠금 해제',
      (tester) async {
    await _pump(tester, (status: 'acked', result: 'busy'));
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(_switchOn(tester), isTrue);

    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('module_command_busy'), findsOneWidget);
    expect(_switchOn(tester), isFalse);
    expect(find.byKey(DeviceControlSheet.loadingKey), findsNothing);
    expect(_tileTap(tester, CageControlGrid.coolFanKey), isNotNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('서버가 no_ack로 확정 — 무응답 안내', (tester) async {
    await _pump(tester, (status: 'no_ack', result: 'no_ack'));
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('module_command_no_ack'), findsOneWidget);
    expect(_switchOn(tester), isFalse);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('ACK도 보고도 없이 8초 — 무응답 안내 후 해제', (tester) async {
    await _pump(tester, (status: 'sent', result: null));
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(DeviceControlSheet.loadingKey), findsOneWidget);
    expect(find.text('module_command_no_ack'), findsNothing);

    await tester.pump(kControlPollInterval * kControlConfirmPolls);
    await tester.pump();
    expect(find.text('module_command_no_ack'), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.loadingKey), findsNothing);
    expect(_switchOn(tester), isFalse);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('ACK는 됐는데 보고가 늦음 — 8초 뒤 조용히 해제(겁주지 않는다)',
      (tester) async {
    await _pump(tester, (status: 'acked', result: 'ok'));
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump(const Duration(seconds: 3));
    // 상태가 바뀌는 명령은 ACK만으로 풀지 않는다 — 풀면 스위치가 되돌아갔다 다시 넘어간다.
    expect(find.byKey(DeviceControlSheet.loadingKey), findsOneWidget);
    await tester.pump(kControlPollInterval * kControlConfirmPolls);
    await tester.pump();
    expect(find.byKey(DeviceControlSheet.loadingKey), findsNothing);
    expect(find.text('module_command_no_ack'), findsNothing);
    expect(find.text('module_command_busy'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('상태 모름 LED(구 펌웨어) — 목표 상태를 꾸며 그리지 않고 ACK로 1초 만에 해제',
      (tester) async {
    final (sent, _) = await _pump(tester, (status: 'acked', result: 'ok'),
        device: ScheduleDevice.led);
    await tester.tap(find.byKey(const Key('led_on')));
    await tester.pump();
    expect(sent.single.$1, CommandAction.ledOn);
    // 대기 중에도 켜기/끄기 버튼 그대로("상태 모름" 유지), 타일도 켜짐으로 안 바뀐다.
    expect(find.byKey(const Key('led_on')), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.powerSwitchKey), findsNothing);
    expect(find.text('device_state_on'), findsNothing);
    // 보고를 8초 기다리지 않는다 — 첫 ACK 조회에서 풀린다.
    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byKey(CageControlGrid.loadingKey), findsNothing);
    expect(_tileTap(tester, CageControlGrid.ventFanKey), isNotNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('분무 실행 취소 창 동안 다른 타일 잠금 — 겹쳐서 분무가 삼켜지지 않는다',
      (tester) async {
    final (sent, _) = await _pump(tester, (status: 'acked', result: 'ok'),
        device: ScheduleDevice.mist);
    await tester.tap(find.byKey(DeviceControlSheet.mistStartKey));
    await tester.pump();
    expect(sent, isEmpty);
    expect(_tileTap(tester, CageControlGrid.ventFanKey), isNull);
    expect(find.byKey(CageControlGrid.loadingKey), findsOneWidget);

    await tester.pump(kMistUndoWindow + const Duration(milliseconds: 100));
    expect(sent.single.$1, CommandAction.mist);
    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    await tester.pump();
    expect(_tileTap(tester, CageControlGrid.ventFanKey), isNotNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('다른 제어 대기 중 분무 전송 시도 — 보내지 않고 실패 토스트', (tester) async {
    final (sent, _) = await _pump(tester, (status: 'sent', result: null),
        device: ScheduleDevice.mist);
    final ctx = tester.element(find.byType(DeviceControlSheet));
    final container = ProviderScope.containerOf(ctx);
    container
        .read(controlPendingProvider(kTestDeviceId).notifier)
        .begin(ScheduleDevice.fan, true);
    unawaited(sendMistWith(container, ScaffoldMessenger.of(ctx), kTestDeviceId,
        MistDuration.sevenSeconds,
        toastContext: ctx));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('home_mist_failed_toast'), findsOneWidget);
    container.read(controlPendingProvider(kTestDeviceId).notifier).cancel();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('분무 거절 — 잠금을 바로 풀어 타일이 "작동 중"으로 남지 않는다',
      (tester) async {
    await _pump(tester, (status: 'rejected', result: null),
        device: ScheduleDevice.mist);
    final ctx = tester.element(find.byType(DeviceControlSheet));
    final container = ProviderScope.containerOf(ctx);
    unawaited(sendMistWith(container, ScaffoldMessenger.of(ctx), kTestDeviceId,
        MistDuration.tenSeconds,
        toastContext: ctx));
    await tester.pump();
    // 송신 직후엔 잠김(분사 중으로 본다).
    expect(
        container
            .read(mistLockProvider(kTestDeviceId))
            .isLocked(DateTime.now()),
        isTrue);
    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    await tester.pump();
    // 거절 확정 — 12초를 기다리지 않고 풀린다.
    expect(
        container
            .read(mistLockProvider(kTestDeviceId))
            .isLocked(DateTime.now()),
        isFalse);
    expect(find.text('device_state_running'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('옛 분무의 만료 타이머는 새 분무의 잠금을 지우지 않는다', (tester) async {
    await _pump(tester, (status: 'rejected', result: null),
        device: ScheduleDevice.mist);
    final ctx = tester.element(find.byType(DeviceControlSheet));
    final container = ProviderScope.containerOf(ctx);
    unawaited(sendMistWith(container, ScaffoldMessenger.of(ctx), kTestDeviceId,
        MistDuration.fiveSeconds,
        toastContext: ctx));
    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    await tester.pump();
    // 거절로 풀린 뒤 다른 곳에서 새 잠금이 걸렸다고 치자.
    final newer = MistLock(lockedUntil: DateTime.now().add(const Duration(minutes: 1)));
    container.read(mistLockProvider(kTestDeviceId).notifier).state = newer;
    // 옛 분무(5초 → 7초 잠금)의 타이머가 돈다.
    await tester.pump(const Duration(seconds: 7));
    expect(
        identical(container.read(mistLockProvider(kTestDeviceId)), newer),
        isTrue);
    await tester.pump(const Duration(seconds: 15));
  });

  test('classifyCommand — 확정 결과 분류', () {
    expect(classifyCommand('acked', 'ok'), ControlOutcome.ok);
    expect(classifyCommand('acked', 'busy'), ControlOutcome.busy);
    expect(classifyCommand('acked', 'error'), ControlOutcome.rejected);
    expect(classifyCommand('rejected', null), ControlOutcome.rejected);
    for (final s in ['no_ack', 'expired', 'lost']) {
      expect(classifyCommand(s, s), ControlOutcome.noResponse);
    }
    expect(classifyCommand('pending', null), isNull);
    expect(classifyCommand('sent', null), isNull);
    expect(classifyCommand(null, null), isNull);
  });
}
