import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/device_mode.dart';
import 'package:tera_ai/features/home/domain/env_extremes.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/cage_control_actions.dart';
import 'package:tera_ai/features/home/presentation/home_control_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/env_mini_chart.dart';
import 'package:tera_ai/features/home/presentation/widgets/live_env_card.dart';
import 'package:tera_ai/features/home/presentation/widgets/quick_control_grid.dart';
import 'package:tera_ai/features/my_cage/domain/actuator_state.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_reading.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';

const _deviceId = 'dev-1';

TelemetryReading _reading() => TelemetryReading(
      deviceId: _deviceId,
      tA: 24.5,
      hA: 68,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: ActuatorState.on,
      heaterState: ActuatorState.off,
      heaterLocked: false,
      ts: DateTime(2026, 8, 8, 12),
    );

List<TelemetryBucket> _buckets() {
  final from = DateTime(2026, 8, 7, 19);
  return [
    for (var i = 0; i < 24; i++)
      TelemetryBucket(
        bucket: from.add(Duration(hours: i)),
        sampleCount: 1,
        tAvg: 23 + (i % 5),
        tMin: 23,
        tMax: 27,
        hAvg: 60 + (i % 8),
        hMin: 58,
        hMax: 72,
      ),
  ];
}

/// 실제 기기 폭으로 제어 서브탭 전체를 세운다.
/// **오버플로가 나면 flutter_test가 예외로 실패**시키므로, 이 테스트 자체가
/// 레이아웃 안전망이다 (큰 리드아웃·가로형 타일이 좁은 화면에서 넘치는지).
///
/// [mode] 기본값이 `cageOnly`인 이유: 통합 세트에서는 [QuickControlGrid]가
/// 라이브 아래 제어 바와 겹쳐서 아예 안 그려진다. 그리드 레이아웃을 재려면
/// 그리드가 나오는 모드로 세워야 한다.
Future<void> _pumpControlTab(
  WidgetTester tester,
  Size size, {
  DeviceMode mode = DeviceMode.cageOnly,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final c = ProviderContainer(overrides: [
    currentDeviceModeProvider.overrideWith((ref) async => mode),
    currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
    telemetryStreamProvider(_deviceId)
        .overrideWith((ref) => Stream.value(_reading())),
    moduleOnlineProvider(_deviceId).overrideWithValue(true),
    todayExtremesProvider.overrideWith(
      (ref) async => EnvExtremes.from(_buckets()),
    ),
    chartBucketsProvider.overrideWith((ref) async => _buckets()),
    actuatorMarkersProvider.overrideWith((ref) async => const []),
    ledBrightnessProvider.overrideWith((ref) => 70),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                LiveEnvCard(),
                EnvMiniChart(),
                QuickControlGrid(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('제어 서브탭 레이아웃 — 오버플로 방지', () {
    testWidgets('iPhone 14 Pro 폭(393)에서 넘치지 않는다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(LiveEnvCard.cardKey), findsOneWidget);
      expect(find.byKey(EnvMiniChart.chartKey), findsOneWidget);
    });

    testWidgets('좁은 기기(320)에서도 넘치지 않는다 — 큰 리드아웃이 위험 지점',
        (tester) async {
      await _pumpControlTab(tester, const Size(320, 640));
      expect(find.byKey(LiveEnvCard.cardKey), findsOneWidget);
    });

    testWidgets('큰 글씨 접근성 설정(textScale 1.5)에서도 넘치지 않는다',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(LiveEnvCard.cardKey), findsOneWidget);
    });
  });

  group('리드아웃', () {
    testWidgets('현재값이 크게 뜬다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.text('24.5'), findsOneWidget);
      expect(find.text('68'), findsOneWidget);
    });

    testWidgets('값이 없으면 0이 아니라 -- 로 둔다', (tester) async {
      final c = ProviderContainer(overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
        telemetryStreamProvider(_deviceId)
            .overrideWith((ref) => Stream.value(null)),
        todayExtremesProvider.overrideWith((ref) async => EnvExtremes.from([])),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: LiveEnvCard())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('--'), findsNWidgets(2));
    });
  });

  group('제어 버튼 중복 방지', () {
    testWidgets('통합 세트(캠+제어기)에서는 2x2 그리드가 안 나온다 — 라이브 아래 바와 같은 4개다',
        (tester) async {
      await _pumpControlTab(tester, const Size(393, 852),
          mode: DeviceMode.integrated);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('사육장 단품에서는 그리드가 유일한 제어 수단이라 남는다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852),
          mode: DeviceMode.cageOnly);
      expect(find.byKey(QuickControlGrid.mistKey), findsOneWidget);
    });
  });

  group('밤 띠', () {
    testWidgets('데이터가 있으면 22~06 구간이 깔린다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(const Key('env_mini_chart_night_bands')),
          findsOneWidget);
    });
  });
}
