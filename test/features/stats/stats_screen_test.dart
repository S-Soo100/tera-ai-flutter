import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/presentation/home_control_providers.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:tera_ai/features/stats/domain/stats_chart_data.dart';
import 'package:tera_ai/features/stats/presentation/stats_providers.dart';
import 'package:tera_ai/features/stats/presentation/stats_screen.dart';
import 'package:tera_ai/features/stats/presentation/widgets/stats_env_chart.dart';
import 'package:tera_ai/features/stats/presentation/widgets/stats_summary_bar.dart';

final _from = DateTime(2026, 8, 4, 19);
final _to = DateTime(2026, 8, 5, 7);

TelemetryBucket _b(DateTime at, double t, double h) => TelemetryBucket(
      bucket: at,
      sampleCount: 1,
      tAvg: t,
      tMin: t,
      tMax: t,
      hAvg: h,
      hMin: h,
      hMax: h,
    );

StatsChartData _chart({bool withData = true}) => StatsChartData.from(
      withData
          ? [
              _b(_from, 23.5, 58),
              _b(DateTime(2026, 8, 4, 23), 25.0, 65),
              _b(_to, 26.0, 72),
            ]
          : const [],
      from: _from,
      to: _to,
    );

Future<void> _pump(
  WidgetTester tester, {
  String? deviceId = 'dev-1',
  StatsChartData? chart,
  Object? error,
}) async {
  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => deviceId),
    todayExtremesProvider.overrideWith((ref) async => throw UnimplementedError()),
    if (deviceId != null)
      telemetryStreamProvider(deviceId).overrideWith((ref) => Stream.value(null)),
    statsChartDataProvider.overrideWith((ref) async {
      if (error != null) throw error;
      return chart ?? _chart();
    }),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: StatsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('제어기가 없으면 안내만 — 빈 차트를 그리지 않는다', (tester) async {
    await _pump(tester, deviceId: null);
    expect(find.byKey(StatsEnvChart.chartKey), findsNothing);
    expect(find.byKey(StatsSummaryBar.barKey), findsNothing);
  });

  testWidgets('데이터가 있으면 차트와 요약 바가 뜬다', (tester) async {
    await _pump(tester);
    expect(find.byKey(StatsEnvChart.chartKey), findsOneWidget);
    expect(find.byKey(StatsSummaryBar.barKey), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('온·습도 두 선을 모두 그린다', (tester) async {
    await _pump(tester);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
  });

  testWidgets('Y는 항상 0~1 정규화 — 단위 다른 두 지표를 겹쳐 그리기 위함',
      (tester) async {
    await _pump(tester);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, 1);
  });

  testWidgets('데이터가 없으면 차트 대신 안내 — 빈 축만 남기지 않는다', (tester) async {
    await _pump(tester, chart: _chart(withData: false));
    expect(find.byKey(StatsEnvChart.chartKey), findsNothing);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('조회 실패를 빈 화면으로 위장하지 않는다', (tester) async {
    await _pump(tester, error: StateError('down'));
    expect(find.byKey(StatsEnvChart.chartKey), findsNothing);
    expect(find.text('stats_load_failed'), findsOneWidget);
  });

  testWidgets('미설계 통계는 대기 중임을 밝힌다 — 고장으로 보이면 안 된다',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(StatsScreen.pendingKey), findsOneWidget);
  });
}
