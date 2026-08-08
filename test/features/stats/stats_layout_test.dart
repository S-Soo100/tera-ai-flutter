import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/presentation/home_control_providers.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:tera_ai/features/stats/domain/stats_chart_data.dart';
import 'package:tera_ai/features/stats/domain/stats_metric.dart';
import 'package:tera_ai/features/stats/domain/stats_period.dart';
import 'package:tera_ai/features/stats/presentation/stats_providers.dart';
import 'package:tera_ai/features/stats/presentation/stats_screen.dart';
import 'package:tera_ai/features/stats/presentation/widgets/stats_env_chart.dart';
import 'package:tera_ai/features/stats/presentation/widgets/stats_period_bar.dart';
import 'package:tera_ai/shared/widgets/pending_section.dart';

final _from = DateTime(2026, 8, 4, 19);
final _to = DateTime(2026, 8, 5, 7);

StatsChartData _chart() => StatsChartData.from(
      [
        for (final e in [
          (_from, 23.5, 58.0),
          (DateTime(2026, 8, 4, 23), 25.0, 65.0),
          (_to, 26.0, 72.0),
        ])
          TelemetryBucket(
            bucket: e.$1,
            sampleCount: 1,
            tAvg: e.$2,
            tMin: e.$2,
            tMax: e.$2,
            hAvg: e.$3,
            hMin: e.$3,
            hMax: e.$3,
          ),
      ],
      from: _from,
      to: _to,
    );

Future<ProviderContainer> _pump(WidgetTester tester, {double width = 402}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => 'dev-1'),
    todayExtremesProvider.overrideWith((ref) async => throw UnimplementedError()),
    telemetryStreamProvider('dev-1').overrideWith((ref) => Stream.value(null)),
    statsChartDataProvider.overrideWith((ref) async => _chart()),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: StatsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  group('레이아웃 — 기획안 §4.3 순서대로 자리를 잡는다', () {
    testWidgets('기간 선택과 메트릭 필터가 차트 위에 있다', (tester) async {
      await _pump(tester);
      expect(find.byKey(StatsPeriodBar.barKey), findsOneWidget);
      expect(find.byKey(StatsMetricFilter.filterKey), findsOneWidget);
    });

    testWidgets('못 만든 섹션은 자리표시자로 남는다 — 빈 화면으로 두지 않는다',
        (tester) async {
      await _pump(tester);
      // §4.3.3 오버레이 + §4.3.4~8 다섯 칸.
      expect(find.byType(PendingSection), findsNWidgets(6));
    });
  });

  group('기간 선택 (§4.3.1)', () {
    testWidgets('기본은 일간 — 실제 차트가 뜬다', (tester) async {
      final c = await _pump(tester);
      expect(c.read(statsPeriodProvider), StatsPeriod.daily);
      expect(find.byKey(StatsEnvChart.chartKey), findsOneWidget);
    });

    testWidgets('주간을 고르면 차트 자리가 자리표시자로 바뀐다 — 사라지지 않는다',
        (tester) async {
      final c = await _pump(tester);
      c.read(statsPeriodProvider.notifier).state = StatsPeriod.weekly;
      await tester.pumpAndSettle();

      expect(find.byKey(StatsEnvChart.chartKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(StatsScreen.mainChartKey),
          matching: find.byType(PendingSection),
        ),
        findsOneWidget,
      );
    });
  });

  group('메트릭 필터 (§4.3.2)', () {
    testWidgets('습도를 끄면 차트가 다시 그려진다 — 눌러도 아무 일 없으면 고장으로 읽힌다',
        (tester) async {
      // 넓게 세운다. 테스트에선 l10n이 없어 .tr()이 긴 키를 그대로 내놓아
      // 칩이 가로 스크롤 밖으로 밀리고, 그러면 탭이 허공에 떨어진다.
      final c = await _pump(tester, width: 1200);
      expect(c.read(statsMetricsProvider).length, 2);

      await tester.tap(find.byKey(StatsMetricFilter.metricKey(StatsMetric.humidity)));
      await tester.pumpAndSettle();

      expect(c.read(statsMetricsProvider), {StatsMetric.temperature});
      expect(find.byKey(StatsEnvChart.chartKey), findsOneWidget);
    });

    testWidgets('활동량은 눌러도 안 켜진다 — 아직 데이터 경로가 없다', (tester) async {
      final c = await _pump(tester, width: 1200);
      await tester.tap(
          find.byKey(StatsMetricFilter.metricKey(StatsMetric.activity)),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(c.read(statsMetricsProvider).contains(StatsMetric.activity),
          isFalse);
    });
  });

  group('toggleMetric — 마지막 하나는 못 끈다', () {
    test('둘 중 하나를 끄면 하나 남는다', () {
      expect(
        toggleMetric(
            {StatsMetric.temperature, StatsMetric.humidity}, StatsMetric.humidity),
        {StatsMetric.temperature},
      );
    });

    test('하나뿐일 때 그걸 끄려 하면 그대로 — 빈 플롯은 고장으로 읽힌다', () {
      expect(
        toggleMetric({StatsMetric.temperature}, StatsMetric.temperature),
        {StatsMetric.temperature},
      );
    });

    test('꺼진 것을 켜면 더해진다', () {
      expect(
        toggleMetric({StatsMetric.temperature}, StatsMetric.humidity),
        {StatsMetric.temperature, StatsMetric.humidity},
      );
    });

    test('준비 안 된 지표는 켜지지 않는다', () {
      expect(
        toggleMetric({StatsMetric.temperature}, StatsMetric.activity),
        {StatsMetric.temperature},
      );
    });
  });
}
