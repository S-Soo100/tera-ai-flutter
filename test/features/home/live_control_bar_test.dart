import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/device_mode.dart';
import 'package:tera_ai/features/home/presentation/home_control_providers.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/live_control_bar.dart';
import 'package:tera_ai/features/my_cage/domain/actuator_state.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_reading.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';

TelemetryReading _reading({
  ActuatorState fan = ActuatorState.off,
  ActuatorState heater = ActuatorState.off,
}) =>
    TelemetryReading(
      deviceId: 'dev-1',
      tA: 24.5,
      hA: 68,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: fan,
      heaterState: heater,
      heaterLocked: false,
      ts: DateTime(2026, 8, 8, 12),
    );

Future<void> _pump(
  WidgetTester tester, {
  required DeviceMode mode,
  String? deviceId = 'dev-1',
  bool online = true,
  TelemetryReading? telemetry,
}) async {
  final c = ProviderContainer(overrides: [
    currentDeviceModeProvider.overrideWith((ref) async => mode),
    currentDeviceIdProvider.overrideWith((ref) async => deviceId),
    if (deviceId != null) ...[
      telemetryStreamProvider(deviceId)
          .overrideWith((ref) => Stream.value(telemetry)),
      moduleOnlineProvider(deviceId).overrideWithValue(online),
    ],
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: LiveControlBar())),
    ),
  );
  await tester.pumpAndSettle();
}

bool _tappable(WidgetTester tester, Key key) {
  final w = tester.widget<InkWell>(
      find.descendant(of: find.byKey(key), matching: find.byType(InkWell)));
  return w.onTap != null;
}

void main() {
  group('노출 조건 — 통합 세트에서만', () {
    testWidgets('integrated → 바가 보인다', (tester) async {
      await _pump(tester, mode: DeviceMode.integrated);
      expect(find.byKey(LiveControlBar.barKey), findsOneWidget);
    });

    testWidgets('cageOnly → 미노출 (위에 라이브가 없어 "보면서 조작"이 성립 안 함)',
        (tester) async {
      await _pump(tester, mode: DeviceMode.cageOnly);
      expect(find.byKey(LiveControlBar.barKey), findsNothing);
    });

    testWidgets('camOnly → 미노출 (제어할 기기가 없음)', (tester) async {
      await _pump(tester, mode: DeviceMode.camOnly);
      expect(find.byKey(LiveControlBar.barKey), findsNothing);
    });

    testWidgets('none → 미노출', (tester) async {
      await _pump(tester, mode: DeviceMode.none);
      expect(find.byKey(LiveControlBar.barKey), findsNothing);
    });

    testWidgets('integrated인데 제어기 id가 없으면 미노출 — 빈 바를 그리지 않는다',
        (tester) async {
      await _pump(tester, mode: DeviceMode.integrated, deviceId: null);
      expect(find.byKey(LiveControlBar.barKey), findsNothing);
    });
  });

  group('오프라인 처리', () {
    testWidgets('오프라인이면 분무를 누를 수 없다 — 닿지 않는 기기에 명령을 쌓지 않는다',
        (tester) async {
      await _pump(tester, mode: DeviceMode.integrated, online: false);
      expect(find.byKey(LiveControlBar.barKey), findsOneWidget);
      expect(_tappable(tester, LiveControlBar.mistKey), isFalse);
    });

    testWidgets('온라인이면 분무를 누를 수 있다', (tester) async {
      await _pump(tester, mode: DeviceMode.integrated, online: true);
      expect(_tappable(tester, LiveControlBar.mistKey), isTrue);
    });
  });

  group('상태 반영', () {
    testWidgets('팬이 켜져 있으면 흰색으로 또렷하게 — 어두운 라이브 면 기준',
        (tester) async {
      await _pump(
        tester,
        mode: DeviceMode.integrated,
        telemetry: _reading(fan: ActuatorState.on),
      );
      // 이 바는 AppTheme.liveSurface(어두운 면) 위에 놓이므로 테마 primary를
      // 쓰지 않는다 — 남색 위 남색은 보이지 않는다.
      final fan = tester.widget<Icon>(find.byIcon(Icons.mode_fan_off));
      expect(fan.color, Colors.white);
    });

    testWidgets('텔레메트리가 없으면 강조하지 않는다 — 모르는 상태를 켜진 것처럼 칠하지 않는다',
        (tester) async {
      await _pump(tester, mode: DeviceMode.integrated, telemetry: null);
      final fan = tester.widget<Icon>(find.byIcon(Icons.mode_fan_off));
      expect(fan.color, isNot(Colors.white));
    });

    testWidgets('LED는 상태 telemetry가 없어 항상 비강조', (tester) async {
      await _pump(
        tester,
        mode: DeviceMode.integrated,
        telemetry: _reading(fan: ActuatorState.on, heater: ActuatorState.on),
      );
      final led = tester.widget<Icon>(find.byIcon(Icons.lightbulb_outline));
      expect(led.color, isNot(Colors.white));
    });
  });
}
