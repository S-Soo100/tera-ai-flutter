// Explicit diagnostic capture, not a simulator or real-device test.
// flutter test --dart-define=CAPTURE_DESIGN=true test/design/final_design_capture_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivnanaut/core/theme/app_theme.dart';
import 'package:vivnanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivnanaut/features/my_cage/presentation/camera_live_fullscreen_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import '../helpers/inert_live_controller.dart';
import 'package:vivnanaut/core/theme/glass_palette.dart';
import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivnanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivnanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/fan_duration_sheet.dart';
import 'package:vivnanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivnanaut/shared/domain/env_day.dart';
import 'package:vivnanaut/shared/domain/week_range.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _Favorite extends Fake implements FavoriteClipRepository {
  @override
  bool isFavorite(String id) => false;
  @override
  File? getLocalFile(String id) => null;
  @override
  FavoriteClip? getMeta(String id) => null;
}

class _Video extends VideoPlayerPlatform {
  int created = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++created;
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    late StreamController<VideoEvent> c;
    c = StreamController(
        onListen: () => c.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 1),
            size: const Size(1920, 1080))),
        onCancel: () async {});
    return c.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async =>
      const Duration(seconds: 12);
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => Builder(
      builder: (context) => ColoredBox(color: context.glass.surfaceTint));
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_DESIGN')) {
    test('opt-in diagnostic captures', () {}, skip: 'CAPTURE_DESIGN=true');
    return;
  }
  final boundary = GlobalKey();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('docs/design-audits/2026-09-14-implementation/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> pump(
      WidgetTester tester, Widget screen, List<Override> overrides) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final scopeKey = UniqueKey();
    await tester.pumpWidget(EasyLocalization(
        assetLoader: const _Translations(),
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        startLocale: const Locale('ko'),
        child: Builder(
            builder: (context) => ProviderScope(
                key: scopeKey,
                overrides: overrides,
                child: MaterialApp(
                    theme: AppTheme.light,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => RepaintBoundary(
                        key: boundary,
                        child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                padding:
                                    const EdgeInsets.only(top: 59, bottom: 34)),
                            child: child!)),
                    home: screen)))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('환경 일간 주간과 팬 선택 진단 캡처', (tester) async {
    final day = EnvDay.of(DateTime.now().subtract(const Duration(days: 1)));
    final week = WeekRange.containing(day.start);
    await pump(tester, const EnvDetailScreen(), [
      currentDeviceIdProvider.overrideWith((ref) async => null),
      envDetailDayProvider.overrideWith((ref) => day),
      envDayBucketsProvider.overrideWith((ref) async => [
            for (var i = 0; i < 48; i++)
              TelemetryBucket(
                  bucket: day.start.add(Duration(minutes: i * 30)),
                  sampleCount: 600,
                  tValidCount: 600,
                  hValidCount: 600,
                  tAvg: 27.5 + (i % 5),
                  tMin: 26,
                  tMax: 32,
                  hAvg: 60 + (i % 6),
                  hMin: 55,
                  hMax: 70)
          ]),
      envDayControlLogProvider.overrideWith((ref) async => []),
      envWeekRowsProvider.overrideWith((ref) async => (
            temp: [
              for (var i = 0; i < 7; i++)
                DayMinMax(
                    day: week.days[i],
                    min: i == 3 || i == 4 ? 23 : 25.0,
                    max: i == 1 ? 33 : 30.0)
            ],
            humid: [
              for (var i = 0; i < 7; i++)
                DayMinMax(
                    day: week.days[i],
                    min: i == 5 ? 50 : 55.0,
                    max: i == 2 ? 72 : 65.0)
            ]
          )),
    ]);
    await tester.pumpAndSettle();
    await capture(tester, 'widget-env-daily');
    await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
    await tester.pumpAndSettle();
    await capture(tester, 'widget-env-weekly');
    await pump(
        tester,
        const Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter, child: FanDurationSheet())),
        []);
    await tester.pumpAndSettle();
    await capture(tester, 'widget-fan-duration');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('세로 가로 왕복은 동일 플레이어 유지, 작은 화면 overflow 없음', (tester) async {
    final video = _Video();
    VideoPlayerPlatform.instance = video;
    await pump(
        tester,
        const ClipPlaylistPlayerScreen(clipId: 'b', playlist: ['a', 'b', 'c']),
        [
          currentUserProvider.overrideWithValue(null),
          favoriteClipRepositoryProvider.overrideWithValue(_Favorite()),
          motionThumbnailFileProvider.overrideWith((ref, key) async => null),
          motionClipProvider.overrideWith((ref, id) async => MotionClip(
              id: id,
              cameraId: 'cam',
              startedAt: DateTime(2026, 8, 28, 10, 21),
              durationSec: 60)),
          motionClipUrlProvider
              .overrideWith((ref, id) async => 'https://example.test/$id'),
        ]);
    await tester.pump(const Duration(seconds: 1));
    await capture(tester, 'widget-player-portrait');
    expect(video.created, 1);
    await tester.tap(find.byKey(const Key('player_speed')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.binding.setSurfaceSize(const Size(852, 393));
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, 'widget-player-landscape');
    expect(video.created, 1);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pump(const Duration(milliseconds: 300));
    expect(video.created, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('라이브는 세로 진입하고 회전해도 연결 controller를 재생성하지 않는다', (tester) async {
    var creates = 0;
    await pump(tester, const CameraLiveFullscreenScreen(cameraId: 'cam'), [
      camerasProvider.overrideWith((ref) => Stream.value([
            TerraCamera(
                id: 'cam',
                cameraId: 'p4',
                name: '라이브',
                isOnline: false,
                createdAt: DateTime(2026))
          ])),
      webrtcLiveControllerProvider.overrideWith((ref, id) {
        creates++;
        return InertLiveController(ref, id);
      }),
    ]);
    await tester.pumpAndSettle();
    expect(creates, 1);
    await tester.tap(find.byKey(const Key('live_fullscreen_orientation')));
    await tester.binding.setSurfaceSize(const Size(852, 393));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('live_fullscreen_orientation')));
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
