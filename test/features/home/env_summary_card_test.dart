import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/env_summary_card.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';

const _deviceId = 'd1';

TelemetryReading _reading({double? t = 28.5, double? h = 62}) =>
    TelemetryReading(
      deviceId: _deviceId,
      tA: t,
      hA: h,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: ActuatorState.off,
      heaterState: ActuatorState.off,
      heaterLocked: false,
      ts: DateTime(2026, 9, 2, 12),
    );

const _extremes = EnvExtremes(
  tempMin: 21.0,
  tempMax: 33.5,
  humidMin: 48.0,
  humidMax: 71.0,
);

Future<void> _pump(
  WidgetTester tester, {
  String? deviceId = _deviceId,
  TelemetryReading? reading,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => deviceId),
        telemetryStreamProvider
            .overrideWith((ref, id) => Stream.value(reading ?? _reading())),
        homeTodayExtremesProvider.overrideWith((ref) async => _extremes),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: EnvSummaryCard()),
        ),
        GoRoute(
          path: '/env-detail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('env-detail-screen'))),
        ),
      ],
    );

void main() {
  testWidgets('온도·습도 2열(현재값 + 오늘 최고/최저)을 그린다', (tester) async {
    await _pump(tester);
    // EasyLocalization 미초기화 → tr()은 키를 그대로 돌려준다.
    expect(find.text('home_live_temp_value'), findsOneWidget);
    expect(find.text('home_live_humid_value'), findsOneWidget);
    expect(find.text('home_env_minmax_temp'), findsOneWidget);
    expect(find.text('home_env_minmax_humid'), findsOneWidget);
  });

  testWidgets('telemetry가 아직 없으면 현재값은 -- 로 그린다', (tester) async {
    await _pump(tester, reading: _reading(t: null, h: null));
    expect(find.text('--'), findsNWidgets(2));
  });

  testWidgets('카드 탭 → /env-detail push (온습도 상세, Task 5 라우트)',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(EnvSummaryCard.cardKey));
    await tester.pumpAndSettle();
    expect(find.text('env-detail-screen'), findsOneWidget);
  });

  testWidgets('기기 없는 세트에서는 카드가 서지 않는다', (tester) async {
    await _pump(tester, deviceId: null);
    expect(find.byKey(EnvSummaryCard.cardKey), findsNothing);
  });
}
