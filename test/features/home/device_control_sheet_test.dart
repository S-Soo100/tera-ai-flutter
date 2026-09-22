import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/presentation/cage_control_actions.dart';
import 'package:vivanaut/features/home/presentation/control_pending.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/home/domain/schedule_device.dart';
import 'package:vivanaut/features/home/presentation/widgets/device_control_sheet.dart';
import 'package:vivanaut/features/home/presentation/widgets/schedule_editor_sheet.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleRow;
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
import 'control_sheet_fixtures.dart';

Future<List<(CommandAction, Map<String, dynamic>?)>> _pump(
  WidgetTester tester,
  ScheduleDevice device, {
  ActuatorState fan = ActuatorState.off,
  ActuatorState fan2 = ActuatorState.off,
  ActuatorState led = ActuatorState.unavailable,
  int? ledBrightness,
  bool dimmable = false,
  List<Schedule> schedules = const [],
  List<RunningTimer> timers = const [],
  DeviceControlTab tab = DeviceControlTab.immediate,
}) async {
  final sent = <(CommandAction, Map<String, dynamic>?)>[];
  await tester.pumpWidget(controlApp(
      Align(
          alignment: Alignment.bottomCenter,
          child: DeviceControlSheet(
              deviceId: kTestDeviceId, device: device, initialTab: tab)),
      controlOverrides(
          sent: sent,
          dimmable: dimmable,
          schedules: schedules,
          timers: timers,
          telemetry: reading(
              fan: fan, fan2: fan2, led: led, ledBrightness: ledBrightness))));
  await tester.pumpAndSettle();
  return sent;
}

/// 송신 후 ACK 감시 타이머(15초+1)를 흘려보낸다.
Future<void> _flush(WidgetTester tester) =>
    tester.pump(kCommandAckGrace + const Duration(seconds: 2));

void main() {
  testWidgets('환기팬 즉시 탭 — segment·전원 행·작동 시간 칩, 선택만으로는 송신 없음',
      (tester) async {
    final sent = await _pump(tester, ScheduleDevice.fan);
    expect(find.byKey(DeviceControlSheet.segmentKey), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.powerRowKey), findsOneWidget);
    expect(find.text('home_sheet_power_fmt'), findsOneWidget);
    // 원본 시트 위 모서리 24.
    expect(
        tester
            .widget<ClipRRect>(find.byKey(DeviceControlSheet.surfaceKey))
            .borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)));
    expect(find.byKey(const Key('fan_timer_10')), findsOneWidget);
    expect(find.byKey(const Key('fan_steady_on')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fan_timer_60')));
    await tester.tap(find.byKey(const Key('fan_steady_on')));
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('환기팬 전원 스위치 켜기 → 고른 시간으로 fan_on 한 번', (tester) async {
    final sent = await _pump(tester, ScheduleDevice.fan);
    await tester.tap(find.byKey(const Key('fan_timer_60')));
    await tester.pump();
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.single.$1, CommandAction.fanOn);
    expect(sent.single.$2, {'duration_ms': 3600000});
    await _flush(tester);
  });

  testWidgets('켜진 환기팬 — 스위치 끄기는 fan_off, 칩 변경은 그 값으로 다시 켠다',
      (tester) async {
    final sent = await _pump(tester, ScheduleDevice.fan,
        fan: ActuatorState.on,
        timers: [
          RunningTimer(
              id: 't',
              deviceId: kTestDeviceId,
              actuatorLabelKey: 'module_actuator_fan',
              durationMinutes: 30,
              endsAt: DateTime.now().add(const Duration(minutes: 20)))
        ]);
    // 진행 중 타이머 30분이 칩 시드다.
    final chip30 = tester.widget<ScheduleChoiceChip>(
        find.byKey(const Key('fan_timer_30')));
    expect(chip30.selected, isTrue);
    await tester.tap(find.byKey(const Key('fan_timer_120')));
    await tester.pump();
    expect(sent.single.$1, CommandAction.fanOn);
    expect(sent.single.$2, {'duration_ms': 7200000});
    // 기기 확인 전에는 시트 전체가 잠겨 있다 — 스위치를 눌러도 안 나간다.
    expect(find.byKey(DeviceControlSheet.loadingKey), findsOneWidget);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent, hasLength(1));
    // 켜진 채 시간만 바꾼 명령은 ACK(1초 뒤 조회)로 확인되고 잠금이 풀린다.
    await tester.pump(kControlPollInterval + const Duration(milliseconds: 100));
    expect(find.byKey(DeviceControlSheet.loadingKey), findsNothing);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.last.$1, CommandAction.fanOff);
    expect(sent.last.$2, isNull);
    await _flush(tester);
  });

  testWidgets('냉각팬 — 종료 안내와 30분/1시간/2시간 뒤 칩, 계속 없음', (tester) async {
    await _pump(tester, ScheduleDevice.cool);
    expect(find.text('home_cooling_end_hint'), findsOneWidget);
    expect(find.byKey(const Key('fan_timer_30')), findsOneWidget);
    expect(find.byKey(const Key('fan_timer_120')), findsOneWidget);
    expect(find.byKey(const Key('fan_timer_10')), findsNothing);
    expect(find.byKey(const Key('fan_steady_on')), findsNothing);
  });

  testWidgets('LED 밝기 보드 — 슬라이더 시드 80(보고 75), 꺼진 채 드래그는 송신 없음, 스위치 켜기 = led_on+brightness',
      (tester) async {
    final sent = await _pump(tester, ScheduleDevice.led,
        dimmable: true, led: ActuatorState.off, ledBrightness: null);
    final slider = tester
        .widget<Slider>(find.byKey(DeviceControlSheet.brightnessSliderKey));
    expect(slider.value, 60);
    expect(slider.min, 20);
    expect(slider.max, 100);
    slider.onChanged!(80);
    slider.onChangeEnd?.call(80);
    await tester.pump();
    expect(sent, isEmpty);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.single.$1, CommandAction.ledOn);
    expect(sent.single.$2, {'brightness': 80});
    await _flush(tester);
  });

  testWidgets('LED 릴레이 보드 — 슬라이더 없이 전원 행만, 끄기는 led_off(payload 없음)',
      (tester) async {
    final sent =
        await _pump(tester, ScheduleDevice.led, led: ActuatorState.on);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('home_led_brightness'), findsNothing);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.single.$1, CommandAction.ledOff);
    expect(sent.single.$2, isNull);
    await _flush(tester);
  });

  testWidgets('분무 — 전원 행 없이 "1회 분사 시작" CTA만', (tester) async {
    await _pump(tester, ScheduleDevice.mist);
    expect(find.byKey(DeviceControlSheet.powerRowKey), findsNothing);
    expect(find.byKey(DeviceControlSheet.mistStartKey), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: find.byKey(DeviceControlSheet.mistStartKey),
                matching: find.byType(FilledButton)))
            .onPressed,
        isNotNull);
  });

  testWidgets('예약 탭 — 목록이 비면 편집기 + "예약 저장", 저장하면 목록으로', (tester) async {
    await _pump(tester, ScheduleDevice.mist, tab: DeviceControlTab.scheduled);
    expect(find.byType(ScheduleEditorBody), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.saveScheduleKey), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.addScheduleKey), findsNothing);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeviceControlSheet.saveScheduleKey));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleRow), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.addScheduleKey), findsOneWidget);
  });

  testWidgets('예약 탭 — 그 기기 예약만 목록에, 새 예약 추가 → 편집기', (tester) async {
    final fanOn = Schedule(
        id: 's1',
        deviceId: kTestDeviceId,
        action: ScheduleAction.mist,
        payload: null,
        kind: ScheduleKind.daily,
        hour: 12,
        minute: 0,
        daysOfWeek: const [],
        enabled: true,
        guard: null,
        pairId: null,
        nextRunAt: null,
        lastRunAt: null);
    final led = Schedule(
        id: 's2',
        deviceId: kTestDeviceId,
        action: ScheduleAction.ledOn,
        payload: null,
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
        enabled: true,
        guard: null,
        pairId: null,
        nextRunAt: null,
        lastRunAt: null);
    await _pump(tester, ScheduleDevice.mist,
        schedules: [fanOn, led], tab: DeviceControlTab.scheduled);
    expect(find.byKey(const Key('schedule_s1')), findsOneWidget);
    expect(find.byKey(const Key('schedule_s2')), findsNothing);
    await tester.tap(find.byKey(DeviceControlSheet.addScheduleKey));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleEditorBody), findsOneWidget);
    // 즉시 탭으로 돌아가면 편집기는 닫힌다.
    await tester.tap(find.byKey(DeviceControlSheet.immediateTabKey));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleEditorBody), findsNothing);
    expect(find.byKey(DeviceControlSheet.mistStartKey), findsOneWidget);
  });

  testWidgets('LED 상태 모름(구 펌웨어) — 스위치 대신 켜기/끄기, 끄기는 led_off',
      (tester) async {
    final sent = await _pump(tester, ScheduleDevice.led,
        led: ActuatorState.unavailable);
    expect(find.byKey(DeviceControlSheet.powerSwitchKey), findsNothing);
    expect(find.byKey(const Key('led_on')), findsOneWidget);
    await tester.tap(find.byKey(const Key('led_off')));
    await tester.pump();
    expect(sent.single.$1, CommandAction.ledOff);
    await _flush(tester);
  });

  testWidgets('전원 스위치 연타 — 왕복 중에는 한 번만 보낸다', (tester) async {
    final sent = await _pump(tester, ScheduleDevice.fan);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.length, 1);
    await _flush(tester);
  });

  testWidgets('분무 — 실행 취소하면 안 보내고, 창이 지나면 mist 3000ms', (tester) async {
    final sent = await _pump(tester, ScheduleDevice.mist);
    await tester.tap(find.byKey(DeviceControlSheet.mistStartKey));
    await tester.pump();
    expect(cancelPendingMist(kTestDeviceId), isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(sent, isEmpty);
    // 5초 잠금이 없으니 바로 다시 누를 수 있다.
    await tester.tap(find.byKey(DeviceControlSheet.mistStartKey));
    await tester.pump(kMistUndoWindow + const Duration(milliseconds: 100));
    expect(sent.single.$1, CommandAction.mist);
    expect(sent.single.$2, {'duration_ms': 3000});
    await tester.pump(const Duration(seconds: 6)); // 잠금 타이머
    await _flush(tester);
  });
}
