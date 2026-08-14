@Tags(['golden'])
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/theme/app_styles.dart';
import 'package:vivnanaut/core/theme/app_theme.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivnanaut/shared/domain/env_chart_data.dart';
import 'package:vivnanaut/shared/domain/chart_window.dart';
import 'package:vivnanaut/features/stats/presentation/stats_providers.dart';
import 'package:vivnanaut/shared/widgets/env_chart.dart';
import 'package:vivnanaut/features/stats/presentation/widgets/stats_summary_bar.dart';

/// 통계 탭 24시 그래프를 실제 위젯 그대로 렌더해 PNG로 남긴다.
///
/// 목적은 회귀 검사가 아니라 **Figma와 눈으로 대조하는 것**이다
/// (`docs/figma-final-design-transcript.md` §3.1). 레이아웃 안전은
/// `stats_layout_test`·`stats_overlay_test`가 맡는다.
///
/// 갱신은 **하나씩** 돌린다. `dart_test.yaml`이 `golden` 태그를 skip으로
/// 묶어두어 `--tags golden`에 `--run-skipped`까지 붙여야 돌고, 두 케이스를
/// 한 번에 돌리면 두 번째가 백지 PNG로 나온다(easy_localization 인스턴스를
/// 두 번 세우는 문제, 홈 골든과 동일 — 2026-08-14 실측 3KB 백지):
/// ```
/// flutter test <이 파일> --update-goldens --tags golden --run-skipped --plain-name "스크럽"
/// flutter test <이 파일> --update-goldens --tags golden --run-skipped --plain-name "다크"
/// ```
///
/// 케이스는 다크 둘(기본·스크럽)뿐이다 — 전역 다크 고정(app.dart)으로
/// 라이트 골든은 삭제했다(홈 골든 `control_light.png` 삭제와 같은 전례).
///
/// ⚠️ **읽을 때 감안할 것 — 하네스 제약이지 앱 상태가 아니다.**
/// - Material 아이콘(해제 ✕ 등)이 빈 네모로 나온다. 골든에 MaterialIcons
///   폰트가 없어서다(홈 골든 `control_dark.png`도 같다). Figma SVG와
///   Pretendard만 직접 로드한다.
///
/// 스크럽 샷은 이제 세로선·점까지 나온다 — 표시를 라이브러리 터치 상태가 아니라
/// provider 값으로 그리기 때문이다(손을 떼도 남기기로 한 결정의 부수 효과).
const _deviceId = 'dev-1';

/// Figma가 그린 프레임과 같은 시각 — 창은 어제 22:00 ~ 오늘 22:00,
/// 회색 밴드는 오른쪽 약 22%.
final _now = DateTime(2026, 8, 10, 16, 40);
final _window = ChartWindow.of(_now);

TelemetryReading _reading() => TelemetryReading(
      deviceId: _deviceId,
      tA: 32,
      hA: 60,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: ActuatorState.on,
      heaterState: ActuatorState.off,
      heaterLocked: false,
      ts: _now,
    );

/// 창 시작부터 지금까지 30분 간격. 밤에 식고 낮에 오르는 야행성 사육장 곡선.
List<TelemetryBucket> _buckets() {
  final out = <TelemetryBucket>[];
  final steps = _now.difference(_window.start).inMinutes ~/ 30;
  for (var i = 0; i <= steps; i++) {
    final at = _window.start.add(Duration(minutes: 30 * i));
    final hour = at.hour + at.minute / 60;
    // 새벽 4시에 최저, 오후 2시에 최고.
    final phase = (hour - 4) / 24 * 2 * math.pi;
    final t = 31 - 5 * math.cos(phase);
    final h = 61 + 9 * math.cos(phase);
    out.add(TelemetryBucket(
      bucket: at,
      sampleCount: 6,
      tAvg: t,
      tMin: t - 0.5,
      tMax: t + 0.5,
      hAvg: h,
      hMin: h - 2,
      hMax: h + 2,
    ));
  }
  return out;
}

/// Figma와 같은 구성: 팬 1 + 분무 2.
List<ActuatorMarker> _markers() => [
      ActuatorMarker(
        kind: MarkerKind.fan,
        at: _window.start.add(const Duration(hours: 3)),
      ),
      ActuatorMarker(
        kind: MarkerKind.mist,
        at: _window.start.add(const Duration(hours: 5, minutes: 30)),
      ),
      ActuatorMarker(
        kind: MarkerKind.mist,
        at: _window.start.add(const Duration(hours: 12)),
      ),
    ];

Future<void> _loadPretendard() async {
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    await loader.load();
  }
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  double? scrub,
}) async {
  // physicalSize는 **물리 픽셀**이다. 논리 393을 원하면 dpr을 곱해야 한다.
  const dpr = 3.0;
  tester.view.physicalSize = const Size(393 * dpr, 220 * dpr);
  tester.view.devicePixelRatio = dpr;

  final buckets = _buckets();
  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
    telemetryStreamProvider(_deviceId)
        .overrideWith((ref) => Stream.value(_reading())),
    chartExtremesProvider.overrideWith((ref) async => EnvExtremes.from(buckets)),
    chartWindowProvider.overrideWith((ref) => _window),
    envChartDataProvider.overrideWith(
      (ref) async => EnvChartData.from(
        buckets,
        from: _window.start,
        to: _window.end,
      ),
    ),
    actuatorMarkersProvider.overrideWith((ref) async => _markers()),
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
            home: Scaffold(
              body: SafeArea(
                child: Consumer(
                  builder: (context, ref, _) {
                    final data = ref.watch(envChartDataProvider).valueOrNull;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppStyles.spacing12),
                        const StatsSummaryBar(),
                        const SizedBox(height: AppStyles.spacing16),
                        if (data != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: EnvChart.outerPadding),
                            child: EnvChart(
                              data: data,
                              window: _window,
                              markers: _markers(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // easy_localization은 번역 로드가 몇 프레임 늦는다. settle만으로는 i18n 키가
  // 그대로 찍힌 화면이 캡처된다.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));

  if (scrub != null) {
    c.read(statsScrubProvider.notifier).state = scrub;
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('preview/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _SharedPreferencesStub.ensure();
    await EasyLocalization.ensureInitialized();
    await _loadPretendard();
  });

  testWidgets('24시 그래프 — 스크럽', (tester) async {
    await _shoot(tester, name: 'stats_24h_scrub', scrub: 0.42);
  });

  testWidgets('24시 그래프 — 다크', (tester) async {
    await _shoot(tester, name: 'stats_24h_dark');
  });
}

/// easy_localization이 저장소 플러그인을 찾으므로 채널을 비워둔다.
class _SharedPreferencesStub {
  static void ensure() {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return null;
    });
  }
}
