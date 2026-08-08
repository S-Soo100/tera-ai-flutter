@Tags(['golden'])
library;


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/core/theme/app_theme.dart';
import 'package:tera_ai/features/home/domain/env_extremes.dart';
import 'package:tera_ai/features/home/presentation/cage_control_actions.dart';
import 'package:tera_ai/features/home/presentation/home_control_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/env_mini_chart.dart';
import 'package:tera_ai/features/home/presentation/widgets/live_env_card.dart';
import 'package:tera_ai/features/home/presentation/widgets/quick_control_grid.dart';
import 'package:tera_ai/features/my_cage/domain/actuator_state.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_reading.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';

/// 사육장 제어 서브탭을 실제 위젯 그대로 렌더해 PNG로 남긴다.
///
/// 목적은 회귀 검사가 아니라 **사람이 눈으로 보는 것**이다 — 레이아웃 안전은
/// `control_tab_layout_test.dart`가 맡고, 여기서는 "이 디자인이 어떻게 보이나"를
/// 확인한다. 그래서 실패 판정을 하지 않고 항상 갱신한다(`--update-goldens`).
///
/// ⚠️ **알려진 제약: 라이트·다크를 한 번에 돌리면 두 번째(다크)가 백지로 나온다.**
/// easy_localization 인스턴스를 두 번 세우는 것과 관련돼 보이나 원인 미확정이다.
/// 추가 pump·tearDown 제거로는 해결되지 않았다. 갱신할 때는 하나씩 돌릴 것:
/// ```
/// flutter test <이 파일> --update-goldens --plain-name "라이트"
/// flutter test <이 파일> --update-goldens --plain-name "다크"
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
    25.8, 25.4, 24.9, 24.3, 23.8, 23.4, 23.1, 22.9, 23.0, 23.3,
    23.9, 24.6, 25.3, 25.9, 26.3, 26.5, 26.2, 25.7,
  ];
  const humids = [
    62.0, 64.0, 67.0, 71.0, 76.0, 80.0, 82.0, 81.0, 78.0, 74.0,
    70.0, 67.0, 64.0, 62.0, 60.0, 59.0, 61.0, 63.0,
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

Future<void> _loadPretendard() async {
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    await loader.load();
  }
}

Future<void> _shoot(
  WidgetTester tester, {
  required Brightness brightness,
  required String name,
}) async {
  // physicalSize는 **물리 픽셀**이다. 논리 393x820을 원하면 dpr을 곱해야 한다 —
  // 안 곱하면 논리 폭이 131px이 되어 화면이 전부 잘린다.
  const dpr = 3.0;
  tester.view.physicalSize = const Size(393 * dpr, 820 * dpr);
  tester.view.devicePixelRatio = dpr;
  // view를 tearDown에서 되돌리지 않는다 — 되돌리면 다음 골든이 잘못된 크기로
  // 시작해 빈 이미지가 나온다(실제로 다크 샷이 백지로 나왔다).

  final c = ProviderContainer(overrides: [
    currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
    telemetryStreamProvider(_deviceId)
        .overrideWith((ref) => Stream.value(_reading())),
    moduleOnlineProvider(_deviceId).overrideWithValue(true),
    todayExtremesProvider.overrideWith((ref) async => EnvExtremes.from(_buckets())),
    chartBucketsProvider.overrideWith((ref) async => _buckets()),
    actuatorMarkersProvider.overrideWith((ref) async => const []),
    ledBrightnessProvider.overrideWith((ref) => 70),
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
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            home: const Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 12),
                      LiveEnvCard(),
                      EnvMiniChart(),
                      SizedBox(height: 16),
                      QuickControlGrid(),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // easy_localization은 두 번째 인스턴스에서 번역 로드가 한 프레임 늦는다.
  // settle만으로는 빈 트리 상태에서 캡처돼 백지 골든이 나온다.
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

  testWidgets('제어 서브탭 — 라이트', (tester) async {
    await _shoot(tester, brightness: Brightness.light, name: 'control_light');
  });

  testWidgets('제어 서브탭 — 다크', (tester) async {
    await _shoot(tester, brightness: Brightness.dark, name: 'control_dark');
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
