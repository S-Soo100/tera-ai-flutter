import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/env_mini_chart.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';
import 'package:vivnanaut/shared/widgets/env_chart.dart';
import 'package:vivnanaut/shared/widgets/env_summary_bar.dart';
import 'package:vivnanaut/shared/widgets/status_badge.dart';
import 'package:vivnanaut/features/home/presentation/widgets/live_env_card.dart';
import 'package:vivnanaut/features/home/presentation/widgets/quick_control_grid.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';

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
Future<void> _pumpControlTab(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
    telemetryStreamProvider(_deviceId)
        .overrideWith((ref) => Stream.value(_reading())),
    moduleOnlineProvider(_deviceId).overrideWithValue(true),
    chartExtremesProvider.overrideWith(
      (ref) async => EnvExtremes.from(_buckets()),
    ),
    // 창을 고정하지 않으면 실제 `now` 기준 구간이 잡혀 고정 시각 버킷이
    // 전부 구간 밖으로 밀린다 → 차트 대신 빈 상태가 뜬다.
    chartWindowProvider
        .overrideWith((ref) => ChartWindow.of(DateTime(2026, 8, 8, 13))),
    chartBucketsProvider.overrideWith((ref) async => _buckets()),
    actuatorMarkersProvider.overrideWith((ref) async => const []),
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

  // 표시 문구는 l10n 템플릿(`{v}°`)을 타므로 테스트에서는 키만 남는다.
  // 그래서 **값이 요약 바까지 제대로 전달되는지**를 본다. 렌더 모양은 골든이 맡는다.
  group('리드아웃', () {
    testWidgets('현재값과 최고/최저가 요약 바로 전달된다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      final bar = tester.widget<EnvSummaryBar>(find.byType(EnvSummaryBar));
      expect(bar.temperature, 24.5);
      expect(bar.humidity, 68);
      expect(bar.extremes, isNotNull);
      expect(bar.extremes!.tempMax, isNotNull);
    });

    // 홈은 훑고 넘어가는 자리라 스크럽을 쓰지 않는다.
    testWidgets('스크럽 표시를 쓰지 않는다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      final bar = tester.widget<EnvSummaryBar>(find.byType(EnvSummaryBar));
      expect(bar.scrubX, isNull);
      expect(bar.onClearScrub, isNull);
      expect(find.byKey(EnvSummaryBar.clearKey), findsNothing);
    });

    testWidgets('값이 없으면 0으로 위장하지 않는다', (tester) async {
      final c = ProviderContainer(overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
        telemetryStreamProvider(_deviceId)
            .overrideWith((ref) => Stream.value(null)),
        chartExtremesProvider.overrideWith((ref) async => EnvExtremes.from([])),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: LiveEnvCard())),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<EnvSummaryBar>(find.byType(EnvSummaryBar));
      expect(bar.temperature, isNull);
      expect(bar.humidity, isNull);
      expect(bar.extremes!.tempMax, isNull);
    });

    // 위험/주의 배지는 뺐다(사용자 결정) — 통계 탭과 같은 표시로 통일했다.
    testWidgets('상태 배지를 그리지 않는다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byType(StatusBadge), findsNothing);
    });
  });

  group('제어 그리드', () {
    testWidgets('제어기가 있으면 2x2 그리드가 나온다 — 사육장 제어의 유일한 진입점이다',
        (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(QuickControlGrid.mistKey), findsOneWidget);
    });
  });

  group('홈 차트', () {
    // 밤 띠는 이제 공용 차트가 그린다. 위젯 트리에 별도 노드가 남지 않으므로
    // **켜져 있는지**를 본다 — 통계 화면은 꺼야 하는 값이라 확인할 값어치가 있다.
    testWidgets('밤 띠를 켠다 — 야행성 개체를 다루는 이 앱의 시그니처다',
        (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      final chart = tester.widget<EnvChart>(find.byType(EnvChart));
      expect(chart.nightBand, isTrue);
    });

    // 홈 차트 전체가 `/stats` 진입점이다. 스크럽이 탭을 가져가면 그 동선이 막힌다.
    testWidgets('스크러버를 켜지 않는다 — 탭은 통계 탭으로 가는 길이다',
        (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      final chart = tester.widget<EnvChart>(find.byType(EnvChart));
      expect(chart.onScrubChanged, isNull);
      expect(chart.scrubX, isNull);
    });
  });
}
