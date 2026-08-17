@Tags(['golden'])
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/theme/app_theme.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';
import 'package:vivnanaut/shared/widgets/wallpaper_background.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/domain/weekly_env_row.dart';
import 'package:vivnanaut/features/home/presentation/widgets/hourly_env_strip.dart';
import 'package:vivnanaut/features/home/presentation/widgets/weekly_env_rows_card.dart';
import 'package:vivnanaut/features/stats/domain/daily_rollup.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/features/home/presentation/widgets/live_env_card.dart';
import 'package:vivnanaut/features/home/presentation/widgets/quick_control_grid.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';

/// 사육장 제어 서브탭을 실제 위젯 그대로 렌더해 PNG로 남긴다.
///
/// 목적은 회귀 검사가 아니라 **사람이 눈으로 보는 것**이다 — 레이아웃 안전은
/// `control_tab_layout_test.dart`가 맡고, 여기서는 "이 디자인이 어떻게 보이나"를
/// 확인한다. 그래서 실패 판정을 하지 않고 항상 갱신한다(`--update-goldens`).
///
/// **케이스는 하나뿐이다.** 전역 다크 고정(`app.dart`의 `themeMode: dark`) +
/// 홈의 월페이퍼·다크 래핑 때문에 라이트/다크 케이스가 바이트 동일 PNG를
/// 만들어, 라이트 케이스를 지웠다.
///
/// 갱신 (`--tags golden`만으로는 dart_test.yaml의 tag skip에 걸려 돌지 않는다
/// — `--run-skipped`가 필수, `--plain-name`은 skip 때문에 매치되지 않는다):
/// ```
/// flutter test --tags golden --run-skipped \
///   test/features/home/control_tab_golden_test.dart --update-goldens
/// ```
///
/// Pretendard를 직접 로드하고 ko 번역을 초기화한다. 안 하면 글자가 네모로
/// 나오고 문구가 i18n 키로 찍혀 실제 화면과 전혀 달라진다.
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
      ts: DateTime(2026, 8, 8, 3),
    );

/// 전날 19:00 ~ 당일 12:00. 밤 띠(22~06)가 가운데 걸리도록.
List<TelemetryBucket> _buckets() {
  final from = DateTime(2026, 8, 7, 19);
  const temps = [
    25.8,
    25.4,
    24.9,
    24.3,
    23.8,
    23.4,
    23.1,
    22.9,
    23.0,
    23.3,
    23.9,
    24.6,
    25.3,
    25.9,
    26.3,
    26.5,
    26.2,
    25.7,
  ];
  const humids = [
    62.0,
    64.0,
    67.0,
    71.0,
    76.0,
    80.0,
    82.0,
    81.0,
    78.0,
    74.0,
    70.0,
    67.0,
    64.0,
    62.0,
    60.0,
    59.0,
    61.0,
    63.0,
  ];
  return [
    for (var i = 0; i < temps.length; i++)
      TelemetryBucket(
        bucket: from.add(Duration(minutes: 60 * i)),
        sampleCount: 6,
        tAvg: temps[i],
        tMin: temps[i] - 0.4,
        tMax: temps[i] + 0.4,
        hAvg: humids[i],
        hMin: humids[i] - 2,
        hMax: humids[i] + 2,
      ),
  ];
}

/// 8/2~8/8(오늘) 일간 — "이번 주" 7행용. 손으로 적은 결정적 값.
List<TelemetryBucket> _weekBuckets() {
  const rows = [
    // day, tMin, tMax, hAvg
    (2, 23.1, 27.4, 66.0),
    (3, 23.6, 28.2, 63.0),
    (4, 22.8, 26.9, 69.0),
    (5, 24.0, 28.8, 60.0),
    (6, 23.4, 27.7, 64.0),
    (7, 22.9, 27.1, 67.0),
    (8, 23.0, 26.5, 71.0),
  ];
  return [
    for (final (d, lo, hi, h) in rows)
      TelemetryBucket(
        bucket: DateTime(2026, 8, d, 12),
        sampleCount: 6,
        tAvg: (lo + hi) / 2,
        tMin: lo,
        tMax: hi,
        hAvg: h,
        hMin: h - 3,
        hMax: h + 3,
      ),
  ];
}

/// 이번 주 분무 이력 — 오늘 2회, 어제 1회, 8/5 3회.
List<ActuatorMarker> _weekMarkers() => [
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 8, 9)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 8, 12)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 7, 20)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 5, 9)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 5, 15)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 5, 21)),
    ];

/// 24h 창의 기기 동작 — 시간대 스트립 아이콘용.
List<ActuatorMarker> _dayMarkers() => [
      ActuatorMarker(kind: MarkerKind.heater, at: DateTime(2026, 8, 7, 21, 40)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 7, 23, 50)),
      ActuatorMarker(kind: MarkerKind.led, at: DateTime(2026, 8, 8, 7, 5)),
      ActuatorMarker(kind: MarkerKind.mist, at: DateTime(2026, 8, 8, 12)),
      ActuatorMarker(kind: MarkerKind.fan, at: DateTime(2026, 8, 8, 12, 30)),
    ];

Future<void> _loadPretendard() async {
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, {required String name}) async {
  // physicalSize는 **물리 픽셀**이다. 논리 393x820을 원하면 dpr을 곱해야 한다 —
  // 안 곱하면 논리 폭이 131px이 되어 화면이 전부 잘린다.
  const dpr = 3.0;
  tester.view.physicalSize = const Size(393 * dpr, 820 * dpr);
  tester.view.devicePixelRatio = dpr;

  final homeWeekly = ChartWindow.homeWeekly(DateTime(2026, 8, 8, 13));
  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
    telemetryStreamProvider(_deviceId)
        .overrideWith((ref) => Stream.value(_reading())),
    moduleOnlineProvider(_deviceId).overrideWithValue(true),
    chartExtremesProvider
        .overrideWith((ref) async => EnvExtremes.from(_buckets())),
    // 창을 고정하지 않으면 실제 `now` 기준이라 고정 시각 버킷이 구간 밖으로
    // 밀려 빈 차트가 찍힌다.
    chartWindowProvider
        .overrideWith((ref) => ChartWindow.of(DateTime(2026, 8, 8, 13))),
    chartBucketsProvider.overrideWith((ref) async => _buckets()),
    actuatorMarkersProvider.overrideWith((ref) async => _dayMarkers()),
    homeWeeklyWindowProvider.overrideWith((ref) => homeWeekly),
    homeWeeklyRowsProvider.overrideWith(
      (ref) async => WeeklyEnvRows.from(
        days: rollupByDay(_weekBuckets(), window: homeWeekly),
        window: homeWeekly,
        markers: _weekMarkers(),
      ),
    ),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('ko')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('ko'),
      startLocale: const Locale('ko'),
      child: UncontrolledProviderScope(
        container: c,
        child: Builder(
          builder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: AppTheme.dark,
            // A안(Liquid Glass) 이후 홈은 **월페이퍼 + 다크 테마 래핑** 단일
            // 룩이다(HomeScreen과 같은 조건). 맨 Scaffold에 찍으면 유리가
            // 받칠 바닥이 없어 실제 화면과 전혀 달라진다.
            home: Theme(
              data: AppTheme.dark,
              child: const Scaffold(
                backgroundColor: AppTheme.glassWallpaperTop,
                body: Stack(
                  children: [
                    Positioned.fill(child: WallpaperBackground()),
                    SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 12),
                            LiveEnvCard(),
                            HourlyEnvStrip(),
                            WeeklyEnvRowsCard(),
                            SizedBox(height: 16),
                            QuickControlGrid(),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // easy_localization 번역 로드가 늦을 수 있다 — settle만으로는 빈 트리
  // 상태에서 캡처돼 백지 골든이 나온 적이 있어 여유 pump를 둔다.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('preview/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesLikeStub.ensure();
    await EasyLocalization.ensureInitialized();
    await _loadPretendard();
  });

  testWidgets('제어 서브탭', (tester) async {
    await _shoot(tester, name: 'control_dark');
  });
}

/// easy_localization이 저장소 플러그인을 찾으므로 채널을 비워둔다.
class SharedPreferencesLikeStub {
  static void ensure() {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return null;
    });
  }
}
