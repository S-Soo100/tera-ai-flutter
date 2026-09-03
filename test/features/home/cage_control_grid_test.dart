import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/cage_control_grid.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';

const _deviceId = 'd1';

TelemetryReading _reading({
  ActuatorState fan = ActuatorState.off,
  ActuatorState led = ActuatorState.unavailable,
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
      heaterState: ActuatorState.off,
      heaterLocked: false,
      ts: DateTime(2026, 9, 2, 12),
      led: led,
      ledBrightness: ledBrightness,
    );

Future<void> _pump(
  WidgetTester tester, {
  TelemetryReading? reading,
  bool online = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
        telemetryStreamProvider
            .overrideWith((ref, id) => Stream.value(reading ?? _reading())),
        moduleOnlineProvider(_deviceId).overrideWithValue(online),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CageControlGrid())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('타일 5개(환기팬·분무·냉각팬·히터팬·LED)를 그린다', (tester) async {
    await _pump(tester);
    expect(find.byKey(CageControlGrid.ventFanKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.mistKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.coolFanKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.heatFanKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.ledKey), findsOneWidget);
    expect(find.text('device_vent_fan'), findsOneWidget);
    expect(find.text('device_mist'), findsOneWidget);
    expect(find.text('device_cool_fan'), findsOneWidget);
    expect(find.text('device_heat_fan'), findsOneWidget);
    expect(find.text('device_led'), findsOneWidget);
  });

  testWidgets('냉각팬 탭 → "준비 중인 기기예요" 안내(미배선 — 명령 금지)',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('home_device_not_ready'), findsOneWidget);
  });

  testWidgets('히터팬 탭 → handleHeaterTap 경유 — 2단 안전확인 다이얼로그',
      (tester) async {
    // 리뷰 2026-09-03: 홈 개편으로 히터 제어 도달 경로가 사라져 배선했다.
    // 확인 다이얼로그(과열=폐사 안전 플로우)가 떠야 하고, "준비 중"은 금지.
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.heatFanKey));
    await tester.pumpAndSettle();
    expect(find.text('module_heater_confirm_title'), findsOneWidget);
    expect(find.text('home_device_not_ready'), findsNothing);
  });

  testWidgets('환기팬(꺼짐) 탭 → handleFanTap 경유 — 켜기 방식 시트가 뜬다',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.ventFanKey));
    await tester.pumpAndSettle();
    expect(find.text('home_fan_pick_title'), findsOneWidget);
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
