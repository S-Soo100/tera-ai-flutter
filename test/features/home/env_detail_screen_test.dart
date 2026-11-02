import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/features/home/domain/env_alert.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_alert_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivanaut/features/home/presentation/env_live_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/control_log_list.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_alert_card.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_day_chart.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_range_bar.dart';
import 'package:vivanaut/features/home/presentation/widgets/week_range_chart.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/axis_bounds.dart';
import 'package:vivanaut/shared/domain/control_log.dart';
import 'package:vivanaut/shared/domain/env_chart_data.dart';
import 'package:vivanaut/shared/domain/env_extremes.dart';
import 'package:vivanaut/shared/domain/week_range.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_report_repository.dart';
import 'package:vivanaut/features/home/domain/env_report.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_report_cards.dart';
import 'package:vivanaut/shared/widgets/inline_retry.dart';
import 'package:vivanaut/shared/domain/env_day.dart';
import 'env_v4_screen_fixtures.dart';

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
    humidPoints: empty ? const [] : const [(x: 0.1, y: 0.5), (x: 0.4, y: 0.4)],
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

class _SettingsRepo implements DeviceSettingsRepository {
  _SettingsRepo(this.current);
  final DeviceSettings current;

  @override
  Future<DeviceSettings> get(String deviceId) async => current;

  @override
  Future<DeviceSettings> patch(String deviceId,
          {double? targetTempC,
          double? targetHumidityPct,
          double? targetTempMin,
          double? targetTempMax,
          double? targetHumidMin,
          double? targetHumidMax}) async =>
      current;
}

Future<void> _pump(
  WidgetTester tester, {
  bool empty = false,
  List<ControlLogEntry>? log,
  Future<List<ControlLogEntry>> Function()? loadLog,
  String? deviceId,
  DeviceSettings? settings,
  List<EnvAlert> alerts = const [],
  FakeEnvReportRepository? reports,
  bool weekRowsError = false,
}) async {
  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => deviceId),
        openEnvAlertsProvider.overrideWith((ref) => Stream.value(alerts)),
        if (deviceId != null) ...[
          envLiveViewProvider(deviceId).overrideWithValue(envLiveView(
              EnvLiveReading(
                  deviceId: deviceId,
                  temperature: 22,
                  humidity: 59.4,
                  measuredAt: now),
              now: now,
              online: true)),
          deviceSettingsRepositoryProvider.overrideWithValue(
              _SettingsRepo(settings ?? DeviceSettings(deviceId: deviceId))),
        ],
        envDailyAverageProvider.overrideWith((ref) async =>
            (temperature: 27.5, humidity: 55.0, countUnavailable: false)),
        envDayChartDataProvider
            .overrideWith((ref) async => _chartData(empty: empty)),
        envDayExtremesProvider.overrideWith((ref) async => _extremes),
        envDayControlLogProvider.overrideWith(
            (ref) async => loadLog != null ? await loadLog() : log ?? _log()),
        envWeekRowsProvider.overrideWith((ref) async =>
            weekRowsError ? throw Exception('boom') : _weekRows()),
        envReportRepositoryProvider
            .overrideWithValue(reports ?? FakeEnvReportRepository()),
        currentUserProvider.overrideWith((ref) => envV4User()),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const EnvDetailScreen()),
            GoRoute(
                path: '$kTempHumidSettingPath/:deviceId',
                builder: (_, state) =>
                    Text('setting:${state.pathParameters['deviceId']}')),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _dateLabel(DateTime d) => '${d.year}. ${d.month}. ${d.day}';

void main() {
  testWidgets('제어 기록 조회 실패는 빈 기록과 구분하고 재시도한다', (tester) async {
    var calls = 0;
    await _pump(tester, loadLog: () async {
      if (++calls == 1) throw StateError('network');
      return [];
    });
    expect(find.text('env_log_load_failed'), findsOneWidget);
    expect(find.byKey(ControlLogList.sectionKey), findsNothing);
    // 범위 바(70)가 들어와 기본 800×600 화면에서 재시도 버튼이 아래로 밀린다
    // — 스크롤한 뒤 한 프레임 그려야 탭 좌표가 맞는다.
    await tester.ensureVisible(find.text('retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('env_log_load_failed'), findsNothing);
    expect(find.byKey(ControlLogList.sectionKey), findsOneWidget);
  });
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

  testWidgets('날짜는 → 가 숨어도 가운데에 있다', (tester) async {
    await _pump(tester);
    final width = tester.getSize(find.byType(EnvDetailScreen)).width;
    final today = find.text(_dateLabel(DateTime.now()));
    // 전엔 숨긴 → 자리가 40, ← 가 48이라 4pt 오른쪽으로 밀렸다.
    expect(
        tester.getCenter(today).dx, moreOrLessEquals(width / 2, epsilon: .5));
    await tester.tap(find.byKey(EnvDetailScreen.dayPrevKey));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final yesterday =
        find.text(_dateLabel(DateTime(now.year, now.month, now.day - 1)));
    expect(tester.getCenter(yesterday).dx,
        moreOrLessEquals(width / 2, epsilon: .5));
  });

  testWidgets('날짜 페이저 — ← 어제로, → 다시 오늘로(도착하면 → 숨김)', (tester) async {
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

  testWidgets('세그먼트 — 주간 전환 시 범위 바 2개 + 주 페이저(이번 주 → 숨김)', (tester) async {
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

  testWidgets('기기가 없으면 설정 아이콘을 숨긴다', (tester) async {
    await _pump(tester);
    expect(find.byKey(EnvDetailScreen.closeKey), findsOneWidget);
    expect(find.byKey(EnvDetailScreen.settingsKey), findsNothing);
  });

  testWidgets('설정 아이콘 → 온습도 설정, ✕는 왼쪽·설정은 오른쪽', (tester) async {
    await _pump(tester, deviceId: 'd1');
    final width = tester.getSize(find.byType(EnvDetailScreen)).width;
    expect(tester.getCenter(find.byKey(EnvDetailScreen.closeKey)).dx,
        lessThan(width / 2));
    expect(tester.getCenter(find.byKey(EnvDetailScreen.settingsKey)).dx,
        greaterThan(width / 2));
    await tester.tap(find.byKey(EnvDetailScreen.settingsKey));
    await tester.pumpAndSettle();
    expect(find.text('setting:d1'), findsOneWidget);
  });

  testWidgets('맨 위는 범위 바 두 줄 — 적정 구간은 기기 설정에서', (tester) async {
    await _pump(tester,
        deviceId: 'd1',
        settings: const DeviceSettings(
            deviceId: 'd1',
            targetTempMin: 19,
            targetTempMax: 25.5,
            targetHumidMin: 45,
            targetHumidMax: 75));
    expect(find.byType(EnvRangeBar), findsNWidgets(2));
    expect(find.byKey(EnvRangeBar.bandKey), findsNWidgets(2));
    // 적정 구간 눈금(formatCompact) — 설정값 그대로.
    expect(find.text('19'), findsOneWidget);
    expect(find.text('25.5'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
    // 바 양옆 = 오늘 최저·최고(버림).
    expect(
        tester
            .widget<Text>(find.byKey(const Key('env_range_bar_low_temp')))
            .data,
        '22');
    expect(
        tester
            .widget<Text>(find.byKey(const Key('env_range_bar_high_humid')))
            .data,
        '66');
  });

  final lowDanger = EnvAlert.fromRow({
    'id': 'a1',
    'device_id': 'd1',
    'kind': 'env_temp_low',
    'message': '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요',
    'context': {'rule': 'v4', 'level': 'danger'},
    'triggered_at': '2026-11-02T05:00:00Z',
    'resolved_at': null,
  })!;

  testWidgets('열린 행 0개면 카드 없음', (tester) async {
    await _pump(tester, deviceId: 'd1');
    expect(find.byKey(EnvAlertCard.cardKey), findsNothing);
  });

  testWidgets('오늘 열린 행이 있으면 그래프 아래·제어 기록 위에 카드', (tester) async {
    await _pump(tester, deviceId: 'd1', alerts: [lowDanger]);
    final card = find.byKey(EnvAlertCard.cardKey);
    expect(card, findsOneWidget);
    expect(tester.getRect(card).top,
        greaterThan(tester.getRect(find.byKey(EnvDayChart.chartKey)).bottom));
    await tester.scrollUntilVisible(find.byKey(ControlLogList.sectionKey), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.getRect(find.byKey(ControlLogList.sectionKey)).top,
        greaterThan(tester.getRect(card).bottom));
  });

  testWidgets('지난 날에는 열린 행이 있어도 카드를 그리지 않는다', (tester) async {
    await _pump(tester, deviceId: 'd1', alerts: [lowDanger]);
    await tester.tap(find.byKey(EnvDetailScreen.dayPrevKey));
    await tester.pumpAndSettle();
    expect(find.byKey(EnvAlertCard.cardKey), findsNothing);
  });

  group('일일·주간 분석(계획 2026-11-03 Task 5)', () {
    final yesterday = EnvDay.of(DateTime.now()).previous;
    final lastWeek = WeekRange.containing(DateTime.now()).previous;

    Future<void> toYesterday(WidgetTester tester) async {
      await tester.tap(find.byKey(EnvDetailScreen.dayPrevKey));
      await tester.pumpAndSettle();
    }

    Future<void> toLastWeek(WidgetTester tester) async {
      await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EnvDetailScreen.weekPrevKey));
      await tester.pumpAndSettle();
    }

    testWidgets('today_does_not_query_daily_report', (tester) async {
      final repo = FakeEnvReportRepository();
      await _pump(tester, deviceId: 'd1', reports: repo);
      expect(repo.dailyCalls, isEmpty);
      expect(find.byKey(EnvDailyReportCard.cardKey), findsNothing);
    });

    testWidgets('지난 날 일일 카드 — 그래프 아래·제어 기록 위, 좌우 16', (tester) async {
      final repo =
          FakeEnvReportRepository(daily: envV4DailyReport(yesterday.date));
      await _pump(tester, deviceId: 'd1', reports: repo);
      await toYesterday(tester);
      expect(repo.dailyCalls, ['d1@${envReportDateKey(yesterday.date)}']);
      final card = find.byKey(EnvDailyReportCard.cardKey);
      expect(card, findsOneWidget);
      final rect = tester.getRect(card);
      expect(rect.left, 16);
      expect(rect.top,
          greaterThan(tester.getRect(find.byKey(EnvDayChart.chartKey)).bottom));
      await tester.scrollUntilVisible(
          find.byKey(ControlLogList.sectionKey), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.getRect(find.byKey(ControlLogList.sectionKey)).top,
          greaterThan(tester.getRect(card).bottom));
    });

    testWidgets('daily_caption_shows_report_window', (tester) async {
      await _pump(tester,
          deviceId: 'd1',
          reports:
              FakeEnvReportRepository(daily: envV4DailyReport(yesterday.date)));
      await toYesterday(tester);
      final caption = find.byKey(EnvDetailScreen.dailyReportCaptionKey);
      expect(caption, findsOneWidget);
      expect(tester.getRect(caption).bottom,
          lessThan(tester.getRect(find.byKey(EnvDailyReportCard.cardKey)).top));
    });

    testWidgets('지난 날 행 없음 → 카드·캡션 없음', (tester) async {
      await _pump(tester, deviceId: 'd1', reports: FakeEnvReportRepository());
      await toYesterday(tester);
      expect(find.byKey(EnvDailyReportCard.cardKey), findsNothing);
      expect(find.byKey(EnvDetailScreen.dailyReportCaptionKey), findsNothing);
    });

    testWidgets('daily_report_error_retry', (tester) async {
      final repo = FakeEnvReportRepository(
          daily: envV4DailyReport(yesterday.date), failDaily: 1);
      await _pump(tester, deviceId: 'd1', reports: repo);
      await toYesterday(tester);
      expect(find.byKey(EnvDetailScreen.reportErrorKey), findsOneWidget);
      expect(find.byKey(EnvDailyReportCard.cardKey), findsNothing);
      await tester.tap(find.descendant(
          of: find.byKey(EnvDetailScreen.reportErrorKey),
          matching: find.byType(InlineRetry)));
      await tester.pumpAndSettle();
      expect(find.byKey(EnvDetailScreen.reportErrorKey), findsNothing);
      expect(find.byKey(EnvDailyReportCard.cardKey), findsOneWidget);
    });

    testWidgets('주간 — 온도·습도 차트 아래 각 섹션, 간격 12/36', (tester) async {
      final repo =
          FakeEnvReportRepository(weekly: envV4WeeklyReport(lastWeek.monday));
      await _pump(tester, deviceId: 'd1', reports: repo);
      await toLastWeek(tester);
      expect(repo.weeklyCalls, ['d1@${envReportDateKey(lastWeek.monday)}']);
      final charts = find.byType(WeekRangeChart);
      final tempCard =
          find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.temp));
      expect(tempCard, findsOneWidget);
      expect(tester.getRect(tempCard).top - tester.getRect(charts.first).bottom,
          12);
      // 습도 차트까지 만들어지게 내린다(ListView는 보이는 것만 그린다).
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(charts, findsNWidgets(2));
      expect(tester.getRect(charts.last).top - tester.getRect(tempCard).bottom,
          36);
      await tester.scrollUntilVisible(
          find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.humid)),
          200,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.byKey(EnvWeeklyReportSection.noticeKey(EnvReportElement.humid)),
          findsOneWidget);
    });

    testWidgets('this_week_does_not_query_weekly_report', (tester) async {
      final repo =
          FakeEnvReportRepository(weekly: envV4WeeklyReport(lastWeek.monday));
      await _pump(tester, deviceId: 'd1', reports: repo);
      await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
      await tester.pumpAndSettle();
      expect(repo.weeklyCalls, isEmpty);
      expect(find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.temp)),
          findsNothing);
    });

    testWidgets('weekly_cards_survive_chart_error', (tester) async {
      await _pump(tester,
          deviceId: 'd1',
          weekRowsError: true,
          reports: FakeEnvReportRepository(
              weekly: envV4WeeklyReport(lastWeek.monday)));
      await toLastWeek(tester);
      expect(find.byType(WeekRangeChart), findsNothing);
      expect(find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.temp)),
          findsOneWidget);
    });
  });
}
