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
  testWidgets('타일 4개(환기팬·분무·냉각팬·LED) — 히터 꺼짐이면 히터팬 숨김',
      (tester) async {
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

  testWidgets('냉각팬 탭 → "준비 중인 기기예요" 안내(미배선 — 명령 금지)',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('home_device_not_ready'), findsOneWidget);
  });

  testWidgets('히터 켜짐 → 히터팬 타일 노출 + handleHeaterTap 경유(2단 안전확인)',
      (tester) async {
    // 리뷰 2026-09-04: 예약·웹 콘솔로 켜진 히터를 앱에서 끌 유일한 진입점 —
    // 켜짐/잠금 상태에서 타일이 안 나타나면 과열=폐사 경로가 막힌다.
    await _pump(tester,
        reading: _reading(heaterState: ActuatorState.on));
    await tester.ensureVisible(find.byKey(CageControlGrid.heatFanKey));
    await tester.tap(find.byKey(CageControlGrid.heatFanKey));
    await tester.pumpAndSettle();
    expect(find.text('module_heater_confirm_title'), findsOneWidget);
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
