import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/theme/app_theme.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivnanaut/shared/domain/env_chart_data.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';
import 'package:vivnanaut/features/stats/presentation/stats_providers.dart';
import 'package:vivnanaut/shared/widgets/env_chart.dart';
import 'package:vivnanaut/features/stats/presentation/widgets/stats_summary_bar.dart';
import 'package:vivnanaut/shared/widgets/env_summary_bar.dart';
import 'package:vivnanaut/shared/widgets/figma_icon.dart';

/// Figma SVG 아이콘 하나를 집는다. `FigmaIcon`은 종류가 이름으로만 갈리므로
/// 타입만으로는 분간이 안 된다.
Finder _svg(String name) => find.byWidgetPredicate(
      (w) => w is FigmaIcon && w.name == name,
      description: 'FigmaIcon($name)',
    );

/// 창을 고정해 테스트가 실행 시각에 흔들리지 않게 한다.
/// 16:40 = Figma가 그린 프레임(어제 22시 ~ 오늘 22시).
final _window = ChartWindow.of(DateTime(2026, 8, 10, 16, 40));

EnvChartData _chart() => EnvChartData.from(
      [
        for (final e in [
          (_window.start, 23.5, 58.0),
          (_window.start.add(const Duration(hours: 6)), 25.0, 65.0),
          (_window.start.add(const Duration(hours: 12)), 26.0, 72.0),
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
      from: _window.start,
      to: _window.end,
    );

Future<ProviderContainer> _pumpChart(
  WidgetTester tester, {
  List<ActuatorMarker> markers = const [],
}) async {
  tester.view.physicalSize = const Size(402, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final c = ProviderContainer();
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: EnvChart(
            data: _chart(),
            window: _window,
            markers: markers,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

/// 요약 바만 띄운다.
///
/// **[scrub]은 위젯을 올린 뒤에 넣는다** — [statsScrubProvider]가 autoDispose라
/// 지켜보는 위젯이 없을 때 넣은 값은 그 자리에서 버려진다.
Future<ProviderContainer> _pumpSummary(
  WidgetTester tester, {
  double? scrub,
}) async {
  tester.view.physicalSize = const Size(402, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => 'dev-1'),
    chartExtremesProvider
        .overrideWith((ref) async => throw UnimplementedError()),
    telemetryStreamProvider('dev-1').overrideWith((ref) => Stream.value(null)),
    envChartDataProvider.overrideWith((ref) async => _chart()),
    chartWindowProvider.overrideWith((ref) => _window),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: Scaffold(body: StatsSummaryBar()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (scrub != null) {
    c.read(statsScrubProvider.notifier).state = scrub;
    await tester.pumpAndSettle();
  }
  return c;
}

void main() {
  group('동작 마커 (Figma §3.1)', () {
    testWidgets('마커가 없으면 행이 자리를 차지하지 않는다', (tester) async {
      await _pumpChart(tester);
      expect(find.byKey(EnvChart.markerRowKey), findsNothing);
    });

    testWidgets('창 안의 마커는 칩으로 그려진다', (tester) async {
      await _pumpChart(tester, markers: [
        ActuatorMarker(
          kind: MarkerKind.mist,
          at: _window.start.add(const Duration(hours: 3)),
        ),
        ActuatorMarker(
          kind: MarkerKind.fan,
          at: _window.start.add(const Duration(hours: 9)),
        ),
      ]);
      expect(find.byKey(EnvChart.markerRowKey), findsOneWidget);
      expect(_svg(FigmaIcons.shower), findsOneWidget);
      expect(_svg(FigmaIcons.modeFan), findsOneWidget);
    });

    testWidgets('창 밖 마커는 그리지 않는다 — 차트 밖 동작을 안에 찍으면 거짓말이 된다',
        (tester) async {
      await _pumpChart(tester, markers: [
        ActuatorMarker(
          kind: MarkerKind.mist,
          at: _window.start.subtract(const Duration(hours: 2)),
        ),
      ]);
      expect(_svg(FigmaIcons.shower), findsNothing);
    });

    // 마커는 장식이 아니라 **그 시각에 실제로 돌았다는 기록**이다. 아이콘만
    // 떠 있으면 그 뜻이 안 읽히므로 눌러서 확인할 수 있어야 한다.
    testWidgets('눌러보면 언제 무엇이 실행됐는지 알려준다', (tester) async {
      await _pumpChart(tester, markers: [
        ActuatorMarker(
          kind: MarkerKind.fan,
          at: _window.start.add(const Duration(hours: 6)), // 오전 4시
        ),
      ]);
      final chip = _svg(FigmaIcons.modeFan);
      expect(
        find.ancestor(of: chip, matching: find.byType(Tooltip)),
        findsOneWidget,
      );

      await tester.tap(chip);
      await tester.pumpAndSettle();
      // 번역 미초기화라 키가 그대로 나온다. 문구가 아니라 **뜬다는 사실**을 본다.
      expect(find.text('stats_marker_ran'), findsOneWidget);
    });
  });

  group('미도래 밴드', () {
    test('아직 안 지난 시간이 남아 있으면 밴드 구간이 생긴다', () {
      expect(_window.elapsed, lessThan(1));
    });

    test('밴드 색은 다크에서 뒤집힌다 — 어두운 플롯에 흰 띠가 박히면 안 된다', () {
      expect(AppTheme.chartFutureBand(Brightness.light), AppTheme.lineColor);
      expect(AppTheme.chartFutureBand(Brightness.dark),
          isNot(AppTheme.lineColor));
    });
  });

  group('스크러버 ↔ 요약 바 (Figma 변형 B)', () {
    testWidgets('스크럽 전에는 요약 바가 그대로다', (tester) async {
      await _pumpSummary(tester);
      expect(find.byKey(EnvSummaryBar.scrubKey), findsNothing);
    });

    // 값 자체가 맞는지는 도메인(`stats_chart_data_test`)이 본다. 여기서는
    // **배선** — 스크럽 위치가 시각·지표로 이어지는지 —만 확인한다.
    // (테스트에서 `.tr()`은 번역 없이 키를 그대로 돌려준다.)
    testWidgets('스크럽하면 그 시점 표시로 바뀐다 — 온·습도 둘 다', (tester) async {
      await _pumpSummary(tester, scrub: 0.25);
      final readout = find.byKey(EnvSummaryBar.scrubKey);
      expect(readout, findsOneWidget);
      expect(
        find.descendant(of: readout, matching: _svg(FigmaIcons.thermometer)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: readout, matching: _svg(FigmaIcons.waterDrop)),
        findsOneWidget,
      );
    });

    testWidgets('스크럽 위치에 따라 오전/오후가 갈린다', (tester) async {
      // 창 시작 = 어제 22:00. +6h = 오전 4시, +18h = 오후 4시.
      final c = await _pumpSummary(tester, scrub: 0.25);
      expect(find.text('stats_scrub_time_am'), findsOneWidget);

      c.read(statsScrubProvider.notifier).state = 0.75;
      await tester.pumpAndSettle();
      expect(find.text('stats_scrub_time_pm'), findsOneWidget);
    });

    // 손을 떼도 값은 남는다(사용자 결정) — 읽고, 비교하고, 스크린샷을 찍을 수
    // 있어야 하기 때문이다. 대신 **나가는 문**이 반드시 있어야 한다.
    testWidgets('스크럽 중에는 해제 버튼이 함께 뜬다 — 없으면 최고/최저로 못 돌아간다',
        (tester) async {
      final c = await _pumpSummary(tester);
      expect(find.byKey(EnvSummaryBar.clearKey), findsNothing);

      c.read(statsScrubProvider.notifier).state = 0.25;
      await tester.pumpAndSettle();
      expect(find.byKey(EnvSummaryBar.clearKey), findsOneWidget);
    });

    testWidgets('해제 버튼을 누르면 원래 요약으로 돌아온다', (tester) async {
      final c = await _pumpSummary(tester, scrub: 0.25);
      await tester.tap(find.byKey(EnvSummaryBar.clearKey));
      await tester.pumpAndSettle();
      expect(find.byKey(EnvSummaryBar.scrubKey), findsNothing);
      expect(c.read(statsScrubProvider), isNull);
    });

    testWidgets('오른쪽 끝을 스크럽해도 해제 버튼을 가리지 않는다', (tester) async {
      await _pumpSummary(tester, scrub: 1.0);
      final clear = tester.getRect(find.byKey(EnvSummaryBar.clearKey));
      final readout = tester.getRect(find.byKey(EnvSummaryBar.scrubKey));
      // readout은 Positioned.fill이라 폭이 같다. 실제 글자 블록으로 판정한다.
      final text = tester.getRect(find.byType(FittedBox).first);
      expect(text.right, lessThanOrEqualTo(clear.left + 0.5),
          reason: 'readout=$readout clear=$clear text=$text');
    });

    testWidgets('스크럽해도 요약 바 높이가 변하지 않는다 — 차트가 위아래로 튀면 못 읽는다',
        (tester) async {
      final c = await _pumpSummary(tester);
      final before = tester.getSize(find.byKey(EnvSummaryBar.barKey));

      c.read(statsScrubProvider.notifier).state = 0.5;
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byKey(EnvSummaryBar.barKey));

      expect(after.height, before.height);
    });
  });
}
