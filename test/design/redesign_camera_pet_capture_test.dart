// Opt-in visual verification; only local fixtures, no BLE, WebRTC signaling,
// Supabase rows, image picking, persistence, or remote thumbnail requests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/router/tab_branches.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_report.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_feed_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/crecam_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/camera_live_area.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_form_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'package:vivanaut/shared/widgets/glass_dock.dart';
import 'package:vivanaut/shared/widgets/redesign_tab_header.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? data = jsonDecode(File('$path/ko.json').readAsStringSync());
    return data is Map<String, Object?> ? data : {};
  }
}

class _Pets extends PetRepository {
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [];
}

class _LocalLive extends WebRtcLiveController {
  _LocalLive(super.ref, super.cameraUuid) {
    state = const WebRtcLiveState(
        phase: WebRtcLivePhase.failed, errorKey: 'crecam_live_error_failed');
  }
}

final _day = DateTime(2026, 9, 15);
final _camera = TerraCamera(
    id: 'fixture-camera',
    cameraId: 'fixture-camera-hardware',
    name: '카메라 1',
    isOnline: false,
    enclosureId: 'fixture-group',
    createdAt: _day);
final _set = EnclosureSet(
    enclosure: Enclosure(id: 'fixture-group', name: '사육 환경 1', createdAt: _day),
    device: const Device(
        id: 'fixture-device',
        ownerId: 'fixture-owner',
        enclosureId: 'fixture-group',
        name: '사육장 1',
        isOnline: true,
        lastSeenAt: null),
    camera: _camera,
    pet: null);
final _clips = [
  for (var i = 0; i < 12; i++)
    MotionClip(
        id: 'fixture-clip-$i',
        cameraId: _camera.id,
        startedAt: DateTime(2026, 9, 15, 10 - i ~/ 6, 55 - (i % 6) * 8),
        durationSec: 8)
];

List<Override> _overrides({bool empty = false}) => [
      currentUserProvider.overrideWithValue(User(
          id: 'fixture-owner',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01')),
      clipVisibilityAccountProvider.overrideWithValue(null),
      clipFeedRangeProvider.overrideWith((ref) => null),
      clipFeedProvider.overrideWith((ref, query) {
        final controller = ClipFeedController((cursor) async => (
              items: empty ? <MotionClip>[] : _clips,
              nextCursor: null,
              hasMore: false
            ));
        unawaited(controller.refresh());
        return controller;
      }),
      enclosureSetsProvider.overrideWith((ref) async => empty ? [] : [_set]),
      homeDeviceSetsProvider.overrideWith((ref) async => empty ? [] : [_set]),
      enclosuresProvider
          .overrideWith((ref) async => empty ? [] : [_set.enclosure]),
      camerasProvider
          .overrideWith((ref) => Stream.value(empty ? [] : [_camera])),
      webrtcLiveControllerProvider
          .overrideWith((ref, id) => _LocalLive(ref, id)),
      crecamDayProvider.overrideWith((ref) => null),
      latestMotionClipAtProvider.overrideWith((ref, id) async => _day),
      motionClipsProvider.overrideWith((ref, key) async => empty ? [] : _clips),
      motionThumbnailFileProvider.overrideWith((ref, key) async => null),
      latestHighlightAtProvider.overrideWith((ref) async => _day),
      allFavoriteClipsProvider.overrideWith((ref) async => empty
          ? []
          : [
              FavoriteClip(
                  clipId: _clips.first.id,
                  cameraId: _camera.id,
                  startedAt: _clips.first.startedAt,
                  durationSec: 8,
                  filePath: '/fixture/not-read.mp4',
                  sizeBytes: 0,
                  favoritedAt: _day,
                  ownerId: 'fixture-owner')
            ]),
      isFavoriteProvider.overrideWith((ref, id) => id == _clips.first.id),
      nightlyReportProvider.overrideWith((ref) async =>
          const NightlyReport(activitySeconds: 0, highlights: [])),
      petListProvider.overrideWith((ref) => PetListNotifier(_Pets(), null)),
    ];

Future<void> _settleIcons(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _capture(WidgetTester tester, GlobalKey boundary, String name,
    {bool verifyHeaderPixels = false}) async {
  debugDisableShadows = false;
  try {
    await _settleIcons(tester);
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary.currentContext!.findRenderObject()!);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      if (verifyHeaderPixels) {
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = rgba!.buffer.asUint8List();
        for (final left in [281, 337]) {
          var ink = 0;
          for (var y = 62; y < 106; y++) {
            for (var x = left; x < left + 44; x++) {
              final offset = (y * image.width + x) * 4;
              if (pixels[offset] < 160 &&
                  pixels[offset + 1] < 160 &&
                  pixels[offset + 2] < 160 &&
                  pixels[offset + 3] > 200) {
                ink++;
              }
            }
          }
          expect(ink, greaterThan(20),
              reason:
                  'Header icon at x=$left must actually paint into the PNG');
        }
      }
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/private/tmp/redesign-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_CAMERA_PET')) {
    test('opt-in camera and pet form captures', () {},
        skip: 'CAPTURE_CAMERA_PET=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    for (final name in [
      'nav_home',
      'nav_camera',
      'nav_mycre',
      'nav_community',
      'redesign_v2/discover_tune',
      'person',
      'redesign_v2/arrow_drop_down',
      'cards_star',
      'bookmark_check',
      'calendar_month',
      'live_expand',
      'redesign_v2/add_photo_alternate',
      'redesign_v2/search',
      'redesign_v2/check',
      'arrow_previous',
      'arrow_next',
      'redesign_v2/edit',
      'redesign_v2/calendar_month'
    ]) {
      final path = 'assets/icons/$name.svg';
      if (File(path).existsSync()) {
        final info = await vg.loadPicture(SvgAssetLoader(path), null);
        info.picture.dispose();
      }
    }
  });
  testWidgets('Camera main grid, scrolled state and empty with actual dock',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final measures = <String, Object?>{};
    // Recreate the empty tree once after vector glyphs have painted; otherwise
    // retained SVG layers can be omitted by the headless capture renderer.
    for (final empty in [false, true, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const _Strings(),
          startLocale: const Locale('ko'),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey(empty),
                  overrides: _overrides(empty: empty),
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => RepaintBoundary(
                          key: boundary,
                          child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                  padding: const EdgeInsets.only(
                                      top: 62, bottom: 26)),
                              child: child!)),
                      home: Scaffold(
                          extendBody: true,
                          body: const CrecamScreen(),
                          bottomNavigationBar: GlassDock(items: [
                            for (var i = 0; i < 4; i++)
                              GlassDockItem(
                                  iconAsset: kHomeTabIconAssets[i],
                                  label: kHomeTabLabelKeys[i].tr())
                          ], currentIndex: 1, onSelected: (_) {})))))));
      await _settleIcons(tester);
      await tester.runAsync(() =>
          precacheImage(FigmaImages.emptyCamera, boundary.currentContext!));
      await _capture(tester, boundary, empty ? 'camera-empty' : 'camera-main');
      if (!empty) {
        expect(
            tester.getSize(find.byWidgetPredicate((widget) =>
                widget is FigmaIcon && widget.name == FigmaIcons.liveExpand)),
            const Size(17, 17));
        expect(tester.getSize(find.byKey(CrecamScreen.periodButtonKey)),
            const Size(95, 44));
        expect(tester.getRect(find.byKey(const Key('crecam_period_visual'))),
            const Rect.fromLTWH(286, 493, 95, 40));
        expect(
            tester.getTopLeft(
                find.byKey(const ValueKey('crecam_clip_fixture-clip-0'))),
            const Offset(12, 572));
      }
      Map<String, double> rect(Finder f) {
        final r = tester.getRect(f);
        return {'x': r.left, 'y': r.top, 'width': r.width, 'height': r.height};
      }

      measures[empty ? 'empty' : 'main'] = {
        'header': rect(find.byType(RedesignTabHeader)),
        'dock': rect(find.byType(GlassDock)),
        if (!empty) 'live': rect(find.byType(CameraLiveArea)),
        if (empty) 'image': rect(find.byType(Image)),
        if (empty) 'cta': rect(find.byType(FilledButton)),
        if (!empty)
          'highlight': rect(find.byKey(CrecamScreen.highlightCardKey)),
        if (!empty) 'period': rect(find.byKey(CrecamScreen.periodButtonKey)),
        if (!empty)
          'periodVisual': rect(find.byKey(const Key('crecam_period_visual'))),
        if (!empty)
          'firstClip':
              rect(find.byKey(const ValueKey('crecam_clip_fixture-clip-0'))),
      };
      if (!empty) {
        await tester.drag(
            find.byType(CustomScrollView).first, const Offset(0, -430));
        await _capture(tester, boundary, 'camera-scrolled');
      }
    }
    await tester.runAsync(() =>
        File('/private/tmp/redesign-camera-measurements.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(measures)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('Camera empty isolated SVG capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const _Strings(),
        startLocale: const Locale('ko'),
        child: Builder(
            builder: (context) => ProviderScope(
                key: const ValueKey("isolated-empty"),
                overrides: _overrides(empty: true),
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
                                    const EdgeInsets.only(top: 62, bottom: 26)),
                            child: child!)),
                    home: Scaffold(
                        extendBody: true,
                        body: const CrecamScreen(),
                        bottomNavigationBar: GlassDock(items: [
                          for (var i = 0; i < 4; i++)
                            GlassDockItem(
                                iconAsset: kHomeTabIconAssets[i],
                                label: kHomeTabLabelKeys[i].tr())
                        ], currentIndex: 1, onSelected: (_) {})))))));
    await _settleIcons(tester);
    await tester.runAsync(
        () => precacheImage(FigmaImages.emptyCamera, boundary.currentContext!));
    await _capture(tester, boundary, 'camera-empty-isolated',
        verifyHeaderPixels: true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('Camera period adapts to narrow width and large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final scope = ProviderContainer(overrides: _overrides());
    addTearDown(scope.dispose);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const _Strings(),
        startLocale: const Locale('ko'),
        child: Builder(
            builder: (context) => UncontrolledProviderScope(
                container: scope,
                child: MaterialApp(
                    theme: AppTheme.light,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: const TextScaler.linear(1.7)),
                        child: child!),
                    home: const CrecamScreen())))));
    await _settleIcons(tester);
    expect(tester.getSize(find.byKey(CrecamScreen.periodButtonKey)).height,
        greaterThanOrEqualTo(44));
    scope.read(clipFeedRangeProvider.notifier).state = (
      start: DateTime(2025, 12, 31),
      endExclusive: DateTime(2026, 9, 16),
    );
    await _settleIcons(tester);
    final period = tester.getRect(find.byKey(CrecamScreen.periodButtonKey));
    expect(period.height, greaterThanOrEqualTo(44));
    expect(period.left, greaterThanOrEqualTo(12));
    expect(period.right, lessThanOrEqualTo(308));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('Pet form initial scroll and keyboard long-name validation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const _Strings(),
        startLocale: const Locale('ko'),
        child: Builder(
            builder: (context) => ProviderScope(
                overrides: _overrides(),
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
                                    const EdgeInsets.only(top: 62, bottom: 26)),
                            child: child!)),
                    home: PetFormScreen(onSave: (_, __) async {}))))));
    await _capture(tester, boundary, 'pet-first');
    await tester.tap(find.byKey(const ValueKey('pet-form-species')));
    await tester.pumpAndSettle();
    await _capture(tester, boundary, 'pet-species-popup');
    await tester.tap(find.text('크레스티드 게코').last);
    await tester.pumpAndSettle();
    final nameRect =
        tester.getRect(find.byKey(const ValueKey('pet-form-name')));
    final speciesRect =
        tester.getRect(find.byKey(const ValueKey('pet-form-species')));
    expect(speciesRect.height, 65, reason: 'Figma 765:6880 input height');
    await tester.runAsync(() =>
        File('/private/tmp/redesign-pet-measurements.json')
            .writeAsString(jsonEncode({
          'name': {
            'x': nameRect.left,
            'y': nameRect.top,
            'width': nameRect.width,
            'height': nameRect.height
          },
          'species': {
            'x': speciesRect.left,
            'y': speciesRect.top,
            'width': speciesRect.width,
            'height': speciesRect.height
          }
        })));
    await tester.scrollUntilVisible(find.text('저장'), 450,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('저장'));
    await _capture(tester, boundary, 'pet-scrolled');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pet-form-name')), -450,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byKey(const ValueKey('pet-form-name')), '길고아주긴도마뱀의이름');
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    await _capture(tester, boundary, 'pet-keyboard-long-name');
    expect(find.text('11/10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      'Species dropdown grows for large text and contains a long legacy name',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const _Strings(),
        startLocale: const Locale('ko'),
        child: Builder(
            builder: (context) => ProviderScope(
                overrides: _overrides(),
                child: MaterialApp(
                    theme: AppTheme.light,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: const TextScaler.linear(1.7)),
                        child: child!),
                    home: PetFormScreen(
                        original: Pet(
                            id: 'fixture-legacy',
                            name: '도도',
                            speciesId: 'legacy-species',
                            speciesName: '기존의 매우 긴 종 이름을 유지하는 도마뱀',
                            // Existing empty path shows the local placeholder;
                            // verify its edit badge without file/network IO.
                            photoPath: '',
                            sex: 'male'),
                        onSave: (_, __) async {}))))));
    await _settleIcons(tester);
    expect(
        tester.getSize(find.byWidgetPredicate(
            (widget) => widget is FigmaIcon && widget.name == FigmaIcons.edit)),
        const Size(24, 24));
    await tester.ensureVisible(find.byKey(const ValueKey('pet-form-species')));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const ValueKey('pet-form-species'))).height,
        greaterThan(65));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
