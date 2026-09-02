import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivnanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/control_log_list.dart';
import 'package:vivnanaut/features/home/presentation/widgets/env_day_chart.dart';
import 'package:vivnanaut/features/home/presentation/widgets/week_range_chart.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/shared/domain/axis_bounds.dart';
import 'package:vivnanaut/shared/domain/control_log.dart';
import 'package:vivnanaut/shared/domain/env_chart_data.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';
import 'package:vivnanaut/shared/domain/week_range.dart';

EnvChartData _chartData({bool empty = false}) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  return EnvChartData(
    from: start,
    to: DateTime(start.year, start.month, start.day + 1),
    tempAxis: empty ? null : AxisBounds.forValues([22, 31]),
    humidAxis: empty ? null : AxisBounds.forValues([48, 66]),
    tempPoints: empty
        ? const []
        : const [(x: 0.1, y: 0.3), (x: 0.2, y: 0.6), (x: 0.4, y: 0.8)],
    humidPoints:
        empty ? const [] : const [(x: 0.1, y: 0.5), (x: 0.4, y: 0.4)],
  );
}

const _extremes = EnvExtremes(
  tempMin: 22.0,
  tempMax: 31.0,
  humidMin: 48.0,
  humidMax: 66.0,
);

List<ControlLogEntry> _log() => [
      ControlLogEntry(
        kind: MarkerKind.fan,
        state: ControlLogState.on,
        at: DateTime.now().subtract(const Duration(hours: 2)),
        temperature: 29,
        humidity: 55,
      ),
    ];

({List<DayMinMax> temp, List<DayMinMax> humid}) _weekRows() {
  final week = WeekRange.containing(DateTime.now());
  return (
    temp: [
      for (final d in week.days) DayMinMax(day: d, min: 22, max: 30),
    ],
    humid: [
      for (final d in week.days) DayMinMax(day: d, min: 48, max: 66),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  bool empty = false,
  List<ControlLogEntry>? log,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => null),
        envDayChartDataProvider
            .overrideWith((ref) async => _chartData(empty: empty)),
        envDayExtremesProvider.overrideWith((ref) async => _extremes),
        envDayControlLogProvider
            .overrideWith((ref) async => log ?? _log()),
        envWeekRowsProvider.overrideWith((ref) async => _weekRows()),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const EnvDetailScreen()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _dateLabel(DateTime d) => '${d.year}. ${d.month}. ${d.day}';

void main() {
  testWidgets('일간 기본 — 타이틀·오늘 날짜·차트·제어 기록, → 숨김', (tester) async {
    await _pump(tester);

    expect(find.text('env_detail_title'), findsOneWidget);
    expect(find.text(_dateLabel(DateTime.now())), findsOneWidget);
    expect(find.byKey(EnvDayChart.chartKey), findsOneWidget);
    expect(find.byKey(ControlLogList.sectionKey), findsOneWidget);
    // 오늘은 미래로 못 간다 — → 비표시.
    expect(find.byKey(EnvDetailScreen.dayNextKey), findsNothing);
    expect(find.byKey(EnvDetailScreen.dayPrevKey), findsOneWidget);
  });

  testWidgets('날짜 페이저 — ← 어제로, → 다시 오늘로(도착하면 → 숨김)',
      (tester) async {
    await _pump(tester);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    await tester.tap(find.byKey(EnvDetailScreen.dayPrevKey));
    await tester.pumpAndSettle();
    expect(find.text(_dateLabel(yesterday)), findsOneWidget);
    expect(find.byKey(EnvDetailScreen.dayNextKey), findsOneWidget);

    await tester.tap(find.byKey(EnvDetailScreen.dayNextKey));
    await tester.pumpAndSettle();
    expect(find.text(_dateLabel(now)), findsOneWidget);
    expect(find.byKey(EnvDetailScreen.dayNextKey), findsNothing);
  });

  testWidgets('세그먼트 — 주간 전환 시 범위 바 2개 + 주 페이저(이번 주 → 숨김)',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
    await tester.pumpAndSettle();

    expect(find.byType(WeekRangeChart), findsNWidgets(2));
    expect(find.byKey(EnvDetailScreen.weekNextKey), findsNothing);
    expect(find.byKey(EnvDetailScreen.weekPrevKey), findsOneWidget);

    // 지난주로 가면 →가 나온다.
    await tester.tap(find.byKey(EnvDetailScreen.weekPrevKey));
    await tester.pumpAndSettle();
    expect(find.byKey(EnvDetailScreen.weekNextKey), findsOneWidget);

    // 일간으로 복귀.
    await tester.tap(find.byKey(EnvDetailScreen.segmentDailyKey));
    await tester.pumpAndSettle();
    expect(find.byKey(EnvDayChart.chartKey), findsOneWidget);
  });

  testWidgets('빈 데이터 — 차트 자리에 안내, 기록 없으면 빈 문구', (tester) async {
    await _pump(tester, empty: true, log: const []);

    expect(find.byKey(EnvDayChart.chartKey), findsNothing);
    expect(find.text('env_detail_no_data'), findsOneWidget);
    expect(find.text('env_detail_empty_log'), findsOneWidget);
  });
}
