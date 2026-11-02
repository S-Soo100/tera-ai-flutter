import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivanaut/features/home/presentation/env_live_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/control_log_list.dart';
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
}) async {
  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => deviceId),
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
        envWeekRowsProvider.overrideWith((ref) async => _weekRows()),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const EnvDetailScreen()),
            GoRoute(
                path: '$kTempHumidSettingPath/:deviceId',
                builder: (_, state) => Text(
                    'setting:${state.pathParameters['deviceId']}')),
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
    expect(tester.getCenter(today).dx, moreOrLessEquals(width / 2, epsilon: .5));
    await tester.tap(find.byKey(EnvDetailScreen.dayPrevKey));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final yesterday = find.text(
        _dateLabel(DateTime(now.year, now.month, now.day - 1)));
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
}
