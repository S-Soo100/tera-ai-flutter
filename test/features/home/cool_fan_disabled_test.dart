// 냉각팬을 당분간 꺼 둔 상태(FeatureFlags.coolFanEnabled=false) — 홈 칸은
// "비활성화" + 토스트, 켜져 있던 팬은 시트에서 끄기만 된다(2026-10-16 결정).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/config/feature_flags.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/presentation/widgets/cage_control_grid.dart';
import 'package:vivanaut/features/home/presentation/widgets/device_control_sheet.dart';
import 'package:vivanaut/features/home/domain/schedule_device.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
import 'control_sheet_fixtures.dart';

Future<List<(CommandAction, Map<String, dynamic>?)>> _pumpGrid(
    WidgetTester tester, ActuatorState fan2) async {
  final sent = <(CommandAction, Map<String, dynamic>?)>[];
  await tester.pumpWidget(controlApp(
      const SingleChildScrollView(child: CageControlGrid()),
      controlOverrides(
          sent: sent,
          coolFanEnabled: false,
          telemetry: reading(fan2: fan2))));
  await tester.pumpAndSettle();
  return sent;
}

Future<List<(CommandAction, Map<String, dynamic>?)>> _pumpSheet(
    WidgetTester tester, ActuatorState fan2) async {
  final sent = <(CommandAction, Map<String, dynamic>?)>[];
  await tester.pumpWidget(controlApp(
      const Align(
          alignment: Alignment.bottomCenter,
          child: DeviceControlSheet(
              deviceId: kTestDeviceId, device: ScheduleDevice.cool)),
      controlOverrides(
          sent: sent,
          coolFanEnabled: false,
          telemetry: reading(fan2: fan2))));
  await tester.pumpAndSettle();
  return sent;
}

/// 토스트 타이머(2초)를 흘려보낸다 — 남아 있으면 테스트가 pending timer로 깨진다.
Future<void> _clearToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  test('배포 기본값은 냉각팬 꺼 둠', () {
    expect(FeatureFlags.coolFanEnabled, isFalse);
  });

  testWidgets('꺼진 냉각팬 칸 — "비활성화", 탭하면 토스트만 뜨고 시트·명령 없음',
      (tester) async {
    final sent = await _pumpGrid(tester, ActuatorState.off);
    expect(find.text('device_state_disabled'), findsOneWidget);
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('feature_unavailable_toast'), findsOneWidget);
    expect(find.byKey(DeviceControlSheet.surfaceKey), findsNothing);
    expect(sent, isEmpty);
    await _clearToast(tester);
    expect(find.text('feature_unavailable_toast'), findsNothing);
  });

  testWidgets('fan2 미보고 보드도 꺼 둔 동안엔 같은 "비활성화" + 토스트', (tester) async {
    await _pumpGrid(tester, ActuatorState.unavailable);
    expect(find.text('device_state_disabled'), findsOneWidget);
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('feature_unavailable_toast'), findsOneWidget);
    await _clearToast(tester);
  });

  testWidgets('켜져 있던 냉각팬 칸 — "켜짐", 탭하면 끄기 전용 시트', (tester) async {
    await _pumpGrid(tester, ActuatorState.on);
    expect(find.text('device_state_disabled'), findsNothing);
    expect(find.text('device_state_on'), findsOneWidget);
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pumpAndSettle();
    expect(find.byKey(DeviceControlSheet.surfaceKey), findsOneWidget);
    expect(find.byKey(const Key('cool_fan_off_only_hint')), findsOneWidget);
  });

  testWidgets('끄기 전용 시트 — 예약 탭·종료 칩 없음, 스위치는 fan2_off만',
      (tester) async {
    final sent = await _pumpSheet(tester, ActuatorState.on);
    expect(find.byKey(DeviceControlSheet.segmentKey), findsNothing);
    expect(find.text('home_cooling_end_label'), findsNothing);
    expect(find.byKey(const Key('fan_timer_30')), findsNothing);
    expect(find.byKey(const Key('cool_fan_off_only_hint')), findsOneWidget);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent.single.$1, CommandAction.fan2Off);
    await tester.pump(kCommandAckGrace + const Duration(seconds: 2));
  });

  testWidgets('끄기 전용 시트에서 꺼진 팬은 스위치를 눌러도 켜지지 않는다', (tester) async {
    final sent = await _pumpSheet(tester, ActuatorState.off);
    await tester.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
    await tester.pump();
    expect(sent, isEmpty);
    await _clearToast(tester);
  });
}
