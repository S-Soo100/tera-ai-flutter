import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/domain/weekly_env_row.dart';
import 'package:vivnanaut/features/home/presentation/widgets/hourly_env_strip.dart';
import 'package:vivnanaut/features/home/presentation/widgets/temp_range_bar.dart';
import 'package:vivnanaut/features/home/presentation/widgets/weekly_env_rows_card.dart';
import 'package:vivnanaut/features/stats/domain/daily_rollup.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';
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

/// 8/2~8/8(오늘) 각 날 정오 버킷 — "이번 주" 7행용. 오늘은 8/8 13:00 기준.
List<TelemetryBucket> _weekBuckets() => [
      for (var d = 2; d <= 8; d++)
        TelemetryBucket(
          bucket: DateTime(2026, 8, d, 12),
          sampleCount: 1,
          tAvg: 24.0 + (d % 3),
          tMin: 22.0 + (d % 3),
          tMax: 27.0 + (d % 3),
          hAvg: 60.0 + d,
          hMin: 55,
          hMax: 70,
        ),
    ];

final _homeWeekly = ChartWindow.homeWeekly(DateTime(2026, 8, 8, 13));

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
    homeWeeklyWindowProvider.overrideWith((ref) => _homeWeekly),
    homeWeeklyRowsProvider.overrideWith(
      (ref) async => WeeklyEnvRows.from(
        days: rollupByDay(_weekBuckets(), window: _homeWeekly),
        window: _homeWeekly,
        markers: const [],
      ),
    ),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

/// 행 탭이 `/stats`로 가는지 보려고 라우터를 세운다 — 홈 그대로 두 경로.
/// 테스트마다 새로 만든다 — 공유하면 앞 테스트가 /stats로 옮겨둔 채로 남는다.
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  LiveEnvCard(),
                  HourlyEnvStrip(),
                  WeeklyEnvRowsCard(),
                  QuickControlGrid(),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/stats',
          builder: (_, __) =>
              const Scaffold(body: SizedBox(key: Key('stats_stub'))),
        ),
      ],
    );

void main() {
  group('제어 서브탭 레이아웃 — 오버플로 방지', () {
    testWidgets('iPhone 14 Pro 폭(393)에서 넘치지 않는다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(LiveEnvCard.cardKey), findsOneWidget);
      expect(find.byKey(HourlyEnvStrip.stripKey), findsOneWidget);
      expect(find.byKey(WeeklyEnvRowsCard.cardKey), findsOneWidget);
    });

    testWidgets('좁은 기기(320)에서도 넘치지 않는다 — 큰 리드아웃이 위험 지점', (tester) async {
      await _pumpControlTab(tester, const Size(320, 640));
      expect(find.byKey(LiveEnvCard.cardKey), findsOneWidget);
    });

    testWidgets('큰 글씨 접근성 설정(textScale 1.5)에서도 넘치지 않는다', (tester) async {
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
    testWidgets('제어기가 있으면 2x2 그리드가 나온다 — 사육장 제어의 유일한 진입점이다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(QuickControlGrid.mistKey), findsOneWidget);
    });
  });

  group('홈 온습도 — 애플 날씨 행 문법', () {
    testWidgets('이번 주 7행이 그려지고 오늘이 맨 위다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(WeeklyEnvRowsCard.rowKey(i)), findsOneWidget,
            reason: 'row $i');
      }
      expect(find.byKey(WeeklyEnvRowsCard.rowKey(7)), findsNothing);
      // 오늘 행(0)에만 현재 온도 점이 있다.
      final dot = tester
          .widget<TempRangeBar>(find.byKey(WeeklyEnvRowsCard.todayDotKey));
      expect(dot.dot, isNotNull);
      expect(dot.dot, inInclusiveRange(0, 1));
      expect(
        find.descendant(
            of: find.byKey(WeeklyEnvRowsCard.rowKey(0)),
            matching: find.byKey(WeeklyEnvRowsCard.todayDotKey)),
        findsOneWidget,
      );
      expect(find.byKey(WeeklyEnvRowsCard.todayDotKey), findsOneWidget);
    });

    testWidgets('범위 바 채움은 그날 min~max, 트랙 안(0~1)이다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      final bars = tester.widgetList<TempRangeBar>(find.byType(TempRangeBar));
      expect(bars, hasLength(7));
      for (final b in bars) {
        expect(b.start, isNotNull);
        expect(b.end, isNotNull);
        expect(b.start, inInclusiveRange(0, 1));
        expect(b.end, inInclusiveRange(0, 1));
        expect(b.start! <= b.end!, isTrue);
      }
    });

    testWidgets('행을 누르면 /stats로 간다 — 예전 미니 차트의 동선 승계', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      await tester.ensureVisible(find.byKey(WeeklyEnvRowsCard.rowKey(3)));
      await tester.tap(find.byKey(WeeklyEnvRowsCard.rowKey(3)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stats_stub')), findsOneWidget);
    });

    testWidgets('지난 24시간 스트립은 지금 + 8칸이고 왼쪽 첫 칸이 지금이다', (tester) async {
      await _pumpControlTab(tester, const Size(393, 852));
      expect(find.byKey(HourlyEnvStrip.slotKey(0)), findsOneWidget);
      // 스크롤 밖 칸은 lazy라 안 그려질 수 있다 — 첫 칸 존재와 순서만 본다.
      final first = tester.getTopLeft(find.byKey(HourlyEnvStrip.slotKey(0)));
      final second = tester.getTopLeft(find.byKey(HourlyEnvStrip.slotKey(1)));
      expect(first.dx, lessThan(second.dx));
    });
  });
}
