import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/cage_control_grid.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';

const _deviceId = 'd1';

TelemetryReading _reading({
  ActuatorState fan = ActuatorState.off,
  ActuatorState fan2 = ActuatorState.unavailable,
  ActuatorState led = ActuatorState.unavailable,
  ActuatorState heaterState = ActuatorState.off,
  int? ledBrightness,
}) =>
    TelemetryReading(
      deviceId: _deviceId,
      tA: 28,
      hA: 60,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: fan,
      fan2: fan2,
      heaterState: heaterState,
      heaterLocked: false,
      ts: DateTime(2026, 9, 2, 12),
      led: led,
      ledBrightness: ledBrightness,
    );

Future<void> _pump(
  WidgetTester tester, {
  TelemetryReading? reading,
  bool online = true,
  bool dimmable = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
        telemetryStreamProvider
            .overrideWith((ref, id) => Stream.value(reading ?? _reading())),
        moduleOnlineProvider(_deviceId).overrideWithValue(online),
        deviceListProvider.overrideWith((ref) async => [
              Device(
                id: _deviceId,
                ownerId: null,
                enclosureId: null,
                name: 'test',
                isOnline: online,
                lastSeenAt: null,
                capabilities: {'led_dimmable': dimmable},
              )
            ]),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CageControlGrid())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await ProviderScope.containerOf(tester.element(find.byType(CageControlGrid)))
      .read(deviceListProvider.future);
}

void main() {
  testWidgets('타일 4개(환기팬·분무·냉각팬·LED) — 히터 꺼짐이면 히터팬 숨김', (tester) async {
    // 히터팬 타일은 사용자 지시로 평소 숨김(2026-09-04) — 켜짐/잠금일 때만
    // 나타난다(아래 테스트).
    await _pump(tester);
    expect(find.byKey(CageControlGrid.ventFanKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.mistKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.coolFanKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.ledKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.heatFanKey), findsNothing);
    expect(find.text('device_vent_fan'), findsOneWidget);
    expect(find.text('device_mist'), findsOneWidget);
    expect(find.text('device_cool_fan'), findsOneWidget);
    expect(find.text('device_heat_fan'), findsNothing);
    expect(find.text('device_led'), findsOneWidget);
  });

  testWidgets('냉각팬 미보고는 --로 남으며 탭해도 실행 시트를 열지 않는다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('home_value_none'), findsOneWidget);
    expect(find.text('home_cooling_pick_title'), findsNothing);
  });

  testWidgets('냉각팬 꺼짐 보고 시 냉각팬 전용 시간 선택을 연다', (tester) async {
    await _pump(tester, reading: _reading(fan2: ActuatorState.off));
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pumpAndSettle();
    expect(find.text('home_cooling_pick_title'), findsOneWidget);
    expect(find.byKey(const Key('fan_timer_30')), findsOneWidget);
  });

  testWidgets('밝기 보고 75는 유지하고 선택 값만 80으로 시작, 20~100 10단위', (tester) async {
    await _pump(tester,
        dimmable: true,
        reading: _reading(led: ActuatorState.on, ledBrightness: 75));
    await tester.tap(find.byKey(CageControlGrid.ledKey));
    await tester.pumpAndSettle();
    final slider =
        tester.widget<Slider>(find.byKey(const Key('led_brightness_slider')));
    expect(slider.value, 80);
    expect(slider.min, 20);
    expect(slider.max, 100);
    expect(slider.divisions, 8);
    slider.onChanged!(20);
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 20);
    final context = tester.element(find.byKey(const Key('led_on')));
    expect(
        ProviderScope.containerOf(context)
            .read(telemetryStreamProvider(_deviceId))
            .valueOrNull
            ?.ledBrightness,
        75);
    // 선택 후 닫기만 하면 서버 명령 없이 원래 화면으로 돌아온다.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('밝기 미지원 기기는 슬라이더 없이 켜기/끄기만 표시', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.ledKey));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const Key('led_on')), findsOneWidget);
    expect(find.byKey(const Key('led_off')), findsOneWidget);
  });

  testWidgets('히터 켜짐 → 히터팬 타일 노출 + handleHeaterTap 경유(2단 안전확인)',
      (tester) async {
    // 리뷰 2026-09-04: 예약·웹 콘솔로 켜진 히터를 앱에서 끌 유일한 진입점 —
    // 켜짐/잠금 상태에서 타일이 안 나타나면 과열=폐사 경로가 막힌다.
    await _pump(tester, reading: _reading(heaterState: ActuatorState.on));
    await tester.ensureVisible(find.byKey(CageControlGrid.heatFanKey));
    await tester.tap(find.byKey(CageControlGrid.heatFanKey));
    await tester.pumpAndSettle();
    expect(find.text('module_heater_confirm_title'), findsOneWidget);
  });

  testWidgets('환기팬(꺼짐) 탭은 실행 전 시간 선택 시트를 연다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.ventFanKey));
    await tester.pumpAndSettle();
    // 시트를 열기만 해서는 팬 명령을 보내지 않는다.
    expect(find.text('home_fan_pick_title'), findsOneWidget);
  });

  testWidgets('환기팬 꾹 누르기 → 켜기 방식 시트(계속/타이머)', (tester) async {
    await _pump(tester);
    await tester.longPress(find.byKey(CageControlGrid.ventFanKey));
    await tester.pumpAndSettle();
    expect(find.text('home_fan_pick_title'), findsOneWidget);
    expect(find.byKey(const Key('fan_steady_on')), findsOneWidget);
    expect(find.byKey(const Key('fan_timer_30')), findsOneWidget);
  });

  testWidgets('오프라인이면 환기팬 꾹 누르기도 무반응', (tester) async {
    await _pump(tester, online: false);
    await tester.longPress(find.byKey(CageControlGrid.ventFanKey));
    await tester.pumpAndSettle();
    expect(find.text('home_fan_pick_title'), findsNothing);
  });

  testWidgets('LED unavailable(구 펌웨어) → "상태 모름" — 꺼짐으로 칠하지 않는다',
      (tester) async {
    await _pump(tester);
    expect(find.text('device_state_unknown'), findsOneWidget);
  });

  testWidgets('LED 켜짐 + 밝기 보고 → 퍼센트 표기', (tester) async {
    await _pump(tester,
        reading: _reading(led: ActuatorState.on, ledBrightness: 60));
    expect(find.text('unit_percent_fmt'), findsOneWidget);
  });

  testWidgets('오프라인이면 배선 타일 탭 무반응(시트 없음)', (tester) async {
    await _pump(tester, online: false);
    await tester.tap(find.byKey(CageControlGrid.ventFanKey));
    await tester.pumpAndSettle();
    expect(find.text('home_fan_pick_title'), findsNothing);
  });
}
