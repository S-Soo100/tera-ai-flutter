// P01~P18 after-fix captures. Opt-in only:
//   flutter test --no-pub --dart-define=CAPTURE_REMAINING=true \
//     test/design/remaining_ui_capture_test.dart
// Writes /private/tmp/remaining-after/<name>.png + .json (widget metrics).
// Values/thumbnails come from test fixtures, not devices or servers.
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
import 'package:vivanaut/core/theme/app_theme.dart';
import 'dart:math' as math;
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/control_log.dart';
import 'package:vivanaut/shared/domain/env_day.dart';
import 'package:vivanaut/shared/domain/week_range.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/video_export_service.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/crecam_detail_top_bar.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/wifi_access_point.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_screen.dart';
import '../features/my_cage/device_add_flow_test.dart' show Gateway, device, camera;
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/cage_control_actions.dart';
import 'package:vivanaut/features/home/presentation/widgets/fan_duration_sheet.dart';
import 'package:vivanaut/shared/domain/fan_actuator.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/data/clip_memo_repository.dart';
import 'package:vivanaut/features/my_cage/domain/clip_memo.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmarks_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/pairing_pet_selection_screen.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/domain/pet_form_state.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_form_screen.dart';
import 'package:vivanaut/features/wiki/domain/morph_genetics.dart';
import 'package:vivanaut/features/wiki/presentation/wiki_providers.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

const _outDir = '/private/tmp/remaining-after';

class _Lcd implements LcdRepository {
  @override
  Future<void> setText(String deviceId, String text) async {}
  @override
  Future<void> clear(String deviceId) async {}
}

class _FlowController extends DeviceAddFlowController {
  _FlowController(DeviceAddState initial)
      : super(
            gateway: Gateway(),
            accountId: 'a',
            isCurrent: () => true,
            token: () => '',
            namePrefix: (_) => '기기',
            names: () async => [],
            confirm: (_, __) async => null,
            saveCredentials: (_, __) async {},
            readCredentials: () async => {},
            autoGroup: (_, __) async => 'group') {
    state = initial;
  }
  @override
  Future<void> scan() async {}
  @override
  Future<void> loadNetworks() async {}
  void set(DeviceAddState next) => state = next;
}

class _Favorite extends Fake implements FavoriteClipRepository {
  @override
  bool isFavorite(String id) => false;
  @override
  File? getLocalFile(String id) => null;
  @override
  FavoriteClip? getMeta(String id) => null;
}

class _Export extends Fake implements VideoExportService {
  final done = Completer<void>();
  @override
  Future<void> saveToGallery(String clipId,
      {File? localFile, String? presignedUrl}) async {
    await done.future;
  }
}

class _Video extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
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

class _Memos implements ClipMemoRepository {
  _Memos(this.memos);
  final Map<String, ClipMemo> memos;
  @override
  Future<ClipMemo?> read(String account, String clip) async => memos[clip];
  @override
  Future<void> save(String account, String clip, String text) async {}
  @override
  Future<void> remove(String account, String clip) async {}
}

FavoriteClip _fav(String id, DateTime startedAt) => FavoriteClip(
      clipId: id,
      cameraId: 'cam-1',
      startedAt: startedAt,
      durationSec: 8,
      filePath: '/tmp/$id.mp4',
      sizeBytes: 1,
      favoritedAt: startedAt,
      ownerId: 'a',
    );

class _Pets extends PetRepository {
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [
        Pet(
            id: 'existing',
            name: '도도도',
            speciesId: 'crested-gecko',
            speciesName: '크레스티드 게코')
      ];
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> capture(WidgetTester tester, GlobalKey boundary, String name,
    {bool settle = true}) async {
  // 무한 애니메이션(다운로드 스피너)이 있는 화면은 settle이 끝나지 않는다.
  if (settle) {
    await _settle(tester);
  } else {
    await tester.pump();
  }
  void repaint(RenderObject o) {
    o.markNeedsPaint();
    o.visitChildren(repaint);
  }

  repaint(boundary.currentContext!.findRenderObject()!);
  await tester.pump();
  final rows = <Map<String, dynamic>>[];
  void visit(Element e) {
    final r = e.renderObject;
    final w = e.widget;
    if (r is RenderBox &&
        r.hasSize &&
        (w is Text ||
            w is EditableText ||
            w is FilledButton ||
            w is FigmaIcon ||
            w is IconButton ||
            w is InkWell)) {
      final p = r.localToGlobal(Offset.zero);
      rows.add({
        'type': w.runtimeType.toString(),
        if (w is Text) 'text': w.data ?? w.textSpan?.toPlainText(),
        if (w is EditableText) 'text': w.controller.text,
        if (w is FigmaIcon) 'icon': w.name,
        if (w is InkWell && w.key != null) 'key': w.key.toString(),
        'rect': [p.dx, p.dy, r.size.width, r.size.height],
        if (w is Text) 'style': w.style.toString(),
        if (w is FilledButton) 'enabled': w.onPressed != null,
      });
    }
    e.visitChildren(visit);
  }

  boundary.currentContext!.visitChildElements(visit);
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    File('$_outDir/$name.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    image.dispose();
  });
}

Widget shell(GlobalKey boundary, Widget home,
        {List<Override> overrides = const []}) =>
    ProviderScope(
        key: UniqueKey(),
        overrides: overrides,
        child: EasyLocalization(
            supportedLocales: const [Locale('ko')],
            startLocale: const Locale('ko'),
            path: 'assets/l10n',
            assetLoader: const _Strings(),
            child: Builder(
                builder: (c) => MaterialApp(
                    theme: AppTheme.light,
                    locale: c.locale,
                    supportedLocales: c.supportedLocales,
                    localizationsDelegates: c.localizationDelegates,
                    builder: (c, child) => RepaintBoundary(
                        key: boundary,
                        child: MediaQuery(
                            // 세로 393×852는 상 62/하 34, 가로 프레임(852×393)은
                            // 원본처럼 안전영역 0 — 실기기 노치(59)는 별도 확인.
                            data: MediaQuery.of(c).copyWith(
                                padding: MediaQuery.sizeOf(c).width >
                                        MediaQuery.sizeOf(c).height
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.only(
                                        top: 62, bottom: 34)),
                            child: child!)),
                    home: home))));

void main() {
  if (!const bool.fromEnvironment('CAPTURE_REMAINING')) {
    test('opt-in remaining UI captures', () {},
        skip: 'CAPTURE_REMAINING=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });

  testWidgets('P01 morph search captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(
        boundary, PetFormScreen(original: null, onSave: (_, __) async {}),
        overrides: [
          morphDataProvider('crested-gecko').overrideWith((ref) async =>
              MorphGeneticsData.fromJson(jsonDecode(
                  File('assets/data/morphs/crested-gecko.json')
                      .readAsStringSync()))),
          petListProvider
              .overrideWith((ref) => PetListNotifier(_Pets(), null)),
        ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 안함').first);
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'p01-morph-list');
    for (final (name, query) in [
      ('p01-morph-search-b', 'ㅂ'),
      ('p01-morph-search-initial', 'ㄹ'),
      ('p01-morph-search-english', 'Lilly'),
      ('p01-morph-no-result', 'ㅇㄹㄴㅇㄹ'),
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await capture(tester, boundary, name);
    }
    await tester.tap(find.byKey(const ValueKey('pet-form-morph-clear')));
    await capture(tester, boundary, 'p01-morph-cleared');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P06 device management empty capture', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(boundary, const DeviceManagementScreen(),
        overrides: [
          managementInventoryProvider.overrideWith(
              (ref) async => ManagementInventory(groups: [], items: [])),
          redesignGroupRepositoryProvider.overrideWith((ref) =>
              RedesignGroupRepository(
                  loadRows: (_) async => [], rpc: (_, __) async => null)),
        ]));
    await capture(tester, boundary, 'p06-management-empty');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P07 env detail captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final day = EnvDay.of(DateTime.now().subtract(const Duration(days: 1)));
    final week = WeekRange.containing(day.start);
    await tester.pumpWidget(shell(boundary, const EnvDetailScreen(),
        overrides: [
          currentDeviceIdProvider.overrideWith((ref) async => null),
          envDetailDayProvider.overrideWith((ref) => day),
          envDayBucketsProvider.overrideWith((ref) async => [
                for (var i = 0; i < 48; i++)
                  TelemetryBucket(
                      bucket: day.start.add(Duration(minutes: i * 30)),
                      sampleCount: 600,
                      tValidCount: 600,
                      hValidCount: 600,
                      tAvg: 27.5 + 2.2 * math.sin((i - 12) * math.pi / 48),
                      tMin: 26,
                      tMax: 32,
                      hAvg: 62 - 4 * math.sin((i - 12) * math.pi / 48),
                      hMin: 55,
                      hMax: 70)
              ]),
          envDayControlLogProvider.overrideWith((ref) async => [
                ControlLogEntry(
                    kind: MarkerKind.fan,
                    state: ControlLogState.on,
                    at: day.start.add(const Duration(hours: 8)),
                    temperature: 29.4,
                    humidity: 60.2),
                ControlLogEntry(
                    kind: MarkerKind.fan,
                    state: ControlLogState.off,
                    at: day.start.add(const Duration(hours: 9)),
                    temperature: 27.8,
                    humidity: 62,
                    deltaTemperature: -1.6,
                    deltaHumidity: 1.8),
                ControlLogEntry(
                    kind: MarkerKind.mist,
                    state: ControlLogState.ran,
                    at: day.start.add(const Duration(hours: 13)),
                    temperature: 28.8,
                    humidity: 61),
              ]),
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
        ]));
    await capture(tester, boundary, 'p07-env-daily');
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -420));
    await capture(tester, boundary, 'p07-env-log');
    await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
    await capture(tester, boundary, 'p07-env-weekly');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P13 bookmarks captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    ClipMemo memo(String id, String text, int color) => ClipMemo(
        clipId: id, text: text, colorIndex: color, updatedAt: DateTime.utc(2026));
    await tester.pumpWidget(shell(boundary, const BookmarksScreen(), overrides: [
      allFavoriteClipsProvider.overrideWith((ref) async => [
            _fav('c1', DateTime(2026, 8, 12, 0, 50)),
            _fav('c2', DateTime(2026, 8, 12, 0, 50)),
            _fav('c3', DateTime(2026, 8, 12, 0, 50)),
          ]),
      motionThumbnailFileProvider.overrideWith((ref, clipId) async => null),
      clipMemoAccountProvider.overrideWithValue('a'),
      clipMemoRepositoryProvider.overrideWith((ref) async => _Memos({
            'c1': memo('c1', '눈 귀여워~아아ㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏㅏ', 1),
            'c3': memo('c3', '메모를 합니다 메모를 메메메메메메에ㅔㅔㅔㅔㅔㅔㅔ에ㅔㅔㅇ', 0),
          })),
    ]));
    await capture(tester, boundary, 'p13-bookmarks');
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await capture(tester, boundary, 'p13-bookmarks-menu');
    await tester.tapAt(const Offset(100, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CrecamDetailTopBar.calendarButtonKey));
    await capture(tester, boundary, 'p16-calendar');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P14 player captures', (tester) async {
    debugDisableShadows = false;
    VideoPlayerPlatform.instance = _Video();
    final boundary = GlobalKey();
    Future<void> size(Size s) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(s);
    }

    addTearDown(tester.view.reset);
    await size(const Size(393, 852));
    await tester.pumpWidget(shell(
        boundary,
        const ClipPlaylistPlayerScreen(clipId: 'b', playlist: ['a', 'b', 'c']),
        overrides: [
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
        ]));
    await tester.pump(const Duration(seconds: 1));
    await capture(tester, boundary, 'p14-player-portrait');
    await tester.tapAt(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(300, 300));
    await tester.pump();
    await capture(tester, boundary, 'p14-player-portrait-seek-feedback');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('player_speed')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('player_orientation')));
    await size(const Size(852, 393));
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, boundary, 'p14-player-landscape');
    await tester.tapAt(const Offset(426, 150));
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, boundary, 'p14-player-landscape-hidden');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P16 download captures', (tester) async {
    debugDisableShadows = false;
    VideoPlayerPlatform.instance = _Video();
    final export = _Export();
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(
        boundary,
        const ClipPlaylistPlayerScreen(clipId: 'b', playlist: ['a', 'b', 'c']),
        overrides: [
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
          videoExportServiceProvider.overrideWithValue(export),
        ]));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == FigmaIcons.download));
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, boundary, 'p16-download-progress', settle: false);
    export.done.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, boundary, 'p16-download-done');
    await tester.pump(const Duration(seconds: 3));
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P03-P05 device add flow captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final controller = _FlowController(
        const DeviceAddState(candidates: [device, camera], busy: true));
    await tester.pumpWidget(shell(boundary, const DeviceAddFlowScreen(flowKey: 'cap'),
        overrides: [
          deviceAddAccountProvider.overrideWithValue('a'),
          deviceAddFlowProvider('cap').overrideWith((ref) => controller),
        ]));
    await capture(tester, boundary, 'p03-scan-busy', settle: false);
    controller.set(const DeviceAddState(candidates: [device, camera]));
    await capture(tester, boundary, 'p03-scan-unselected');
    controller.set(const DeviceAddState(
        candidates: [device, camera], selected: {PairTargetKind.device: device}));
    await capture(tester, boundary, 'p03-scan-one');
    controller.set(const DeviceAddState());
    await capture(tester, boundary, 'p03-scan-none');
    controller.set(const DeviceAddState(step: DeviceAddStep.networks, networks: [
      WifiAccessPoint(no: 1, ssid: 'iptime_office', rssi: -30, channel: 1),
      WifiAccessPoint(no: 2, ssid: 'SK_WIFIGIGA88', rssi: -50, channel: 6),
      WifiAccessPoint(no: 3, ssid: 'SK_WIFIGIGA66', rssi: -60, channel: 6),
      WifiAccessPoint(no: 4, ssid: 'SK_WIFIGIGA11', rssi: -70, channel: 11),
    ]));
    await capture(tester, boundary, 'p04-networks');
    controller.set(const DeviceAddState(step: DeviceAddStep.networks));
    await capture(tester, boundary, 'p04-networks-none');
    controller.set(const DeviceAddState(
        step: DeviceAddStep.credentials, ssid: 'iptime_office'));
    await capture(tester, boundary, 'p04-password-empty');
    await tester.enterText(find.byType(TextField), '123456496jsdhoij!#!@');
    await capture(tester, boundary, 'p04-password-filled');
    controller.set(const DeviceAddState(
        step: DeviceAddStep.connecting, ssid: 'iptime_office'));
    await capture(tester, boundary, 'p04-connecting', settle: false);
    controller.set(const DeviceAddState(
        step: DeviceAddStep.results,
        ssid: 'iptime_office',
        results: {
          PairTargetKind.device: DeviceAddResult(
              candidate: device, outcome: DeviceAddOutcome.wifiFailed),
        }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, boundary, 'p04-password-error');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    controller.set(const DeviceAddState(step: DeviceAddStep.results, results: {
      PairTargetKind.device: DeviceAddResult(
          candidate: device,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'd'),
    }));
    await capture(tester, boundary, 'p05-result-device');
    controller.set(const DeviceAddState(step: DeviceAddStep.results, results: {
      PairTargetKind.device: DeviceAddResult(
          candidate: device,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'd'),
      PairTargetKind.camera: DeviceAddResult(
          candidate: camera,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'c'),
    }));
    await capture(tester, boundary, 'p05-result-both');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P05 pet selection captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final now = DateTime(2026, 9, 15);
    Pet pet(String id, String name,
            {String sex = 'unknown', String? morph, double? w}) =>
        Pet(
            id: id,
            name: name,
            speciesId: 'crested-gecko',
            speciesName: '크레스티드 게코',
            sex: sex,
            morph: morph,
            weight: w,
            enclosureId: 'target',
            createdAt: now,
            updatedAt: now);
    ManagementInventory inventory(int count) => ManagementInventory(groups: [
          const ManagementGroup(id: 'target', name: '사육 환경 1'),
        ], items: [
          const ManagementItem(
              key: ManagementKey(kind: ManagementKind.device, id: 'device'),
              name: '온습도계',
              groupId: 'target'),
          for (var i = 0; i < count; i++)
            ManagementItem(
                key: ManagementKey(kind: ManagementKind.pet, id: 'p$i'),
                name: i == 0 ? '크레 이름' : '둘째',
                groupId: i == 0 ? 'target' : null),
        ]);
    Future<void> pumpPets(int count) async {
      await tester.pumpWidget(shell(
          boundary, const PairingPetSelectionScreen(groupId: 'target'),
          overrides: [
            managementInventoryProvider
                .overrideWith((ref) async => inventory(count)),
            redesignGroupRepositoryProvider.overrideWith((ref) =>
                RedesignGroupRepository(
                    loadRows: (_) async => [], rpc: (_, __) async => null)),
            pairingPetsProvider.overrideWith((ref) => [
                  for (var i = 0; i < count; i++)
                    pet('p$i', i == 0 ? '크레 이름' : '둘째',
                        sex: 'female', morph: '아잔틱 릴리 화이트', w: 21),
                ]),
            managementMutationCompletedProvider.overrideWithValue(() {}),
          ]));
      await tester.pumpAndSettle();
    }

    await pumpPets(3);
    await capture(tester, boundary, 'p05-pet-selection');
    await pumpPets(1);
    await capture(tester, boundary, 'p05-pet-single');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P02 group picker and registration complete captures',
      (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(
        boundary,
        PetFormScreen(
            groups: const [
              PetFormGroupOption(
                  id: 'g1',
                  name: '마뱀이네 집',
                  number: 1,
                  hasDevice: true,
                  hasCamera: true),
              PetFormGroupOption(
                  id: 'g2',
                  name: '도도도의 집',
                  number: 2,
                  hasDevice: true,
                  hasCamera: true),
            ],
            onSave: (_, __) async {}),
        overrides: [
          petListProvider
              .overrideWith((ref) => PetListNotifier(_Pets(), null)),
        ]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('그룹 설정'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('그룹 설정'));
    await capture(tester, boundary, 'p02-group-picker');
    await tester.tap(find.byKey(const ValueKey('pet-form-group-g1')));
    await capture(tester, boundary, 'p02-group-picker-selected');
    await tester.tap(find.byKey(const ValueKey('pet-form-group-confirm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pet-form-name')), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('pet-form-name')), '도도');
    await tester.tap(find.byKey(const ValueKey('pet-form-species')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('크레스티드 게코').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-form-save')));
    await capture(tester, boundary, 'p02-pet-done');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P08 LCD captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(boundary, const Scaffold(body: HomeLcdRow()),
        overrides: [
          lcdRepositoryProvider.overrideWithValue(_Lcd()),
          currentSetProvider.overrideWith((ref) async => EnclosureSet(
              enclosure: Enclosure(
                  id: 'e1', name: '1번', createdAt: DateTime(2026, 8, 1)),
              device: Device(
                  id: 'd1',
                  ownerId: null,
                  enclosureId: null,
                  name: null,
                  isOnline: true,
                  lastSeenAt: null),
              camera: null,
              pet: null)),
        ]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await capture(tester, boundary, 'p08-lcd-empty');
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '도도도네 집');
    await capture(tester, boundary, 'p08-lcd-filled');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P09 control sheet captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    for (final (name, sheet) in [
      ('p09-fan', const FanDurationSheet()),
      ('p09-cooling', const FanDurationSheet(actuator: FanActuator.cooling)),
      ('p09-led', const LedControlSheet(dimmable: true)),
    ]) {
      await tester.pumpWidget(shell(
          boundary,
          Scaffold(body: Align(alignment: Alignment.bottomCenter, child: sheet))));
      await capture(tester, boundary, name);
    }
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });
}
