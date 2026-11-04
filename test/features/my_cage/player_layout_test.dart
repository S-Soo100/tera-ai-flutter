import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/video_export_service.dart';
import 'package:vivanaut/features/my_cage/domain/clip_visibility.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_filmstrip.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'package:vivanaut/shared/widgets/video_seek_bar.dart';

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
  int calls = 0;
  @override
  Future<void> saveToGallery(String clipId,
      {File? localFile, String? presignedUrl}) async {
    calls++;
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

/// Figma 941:1834(세로)·941:1928(가로) 실측 좌표.
void main() {
  // 조작줄 폭은 실제 글꼴(Pretendard)로 잰다 — 테스트 기본 글꼴은 글자마다
  // 정사각형이라 시간 알약이 실제보다 두 배 넘게 넓어진다.
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await fonts.load();
  });

  Future<void> pump(WidgetTester tester, Size size,
      {EdgeInsets padding = EdgeInsets.zero,
      _Export? export,
      double textScale = 1,
      Map<String, double> playFromSec = const {},
      List<Override> extra = const []}) async {
    VideoPlayerPlatform.instance = _Video();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(ProviderScope(
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
          if (export != null)
            videoExportServiceProvider.overrideWithValue(export),
          ...extra,
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: padding, textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: ClipPlaylistPlayerScreen(
                clipId: 'b',
                playlist: const ['a', 'b', 'c'],
                playFromSec: playFromSec))));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('portrait: control row 36 at y430, action row y656, strip y716',
      (tester) async {
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34));
    // 영상은 실제 16:9(221.06)라 원본 박스 224보다 3 짧다 → 행 y427.06
    // (헤더 106 + 84 + 221.06 + 시크 16). 원본 좌표 430과의 차이는 영상
    // 비율 때문이며 그 아래 액션 행·스트립은 원본과 같다.
    // 조작줄 — Figma 1689:5771(배속 버튼 수정 261103): 좌우 16, 회색 원·알약.
    final play = tester.getRect(find.byKey(const Key('player_play_pause')));
    expect(play.left, 16);
    expect(play.top, closeTo(430, 3));
    expect(play.size, const Size(36, 36));
    final timePill = tester.getRect(find.byKey(const Key('player_time_pill')));
    expect(timePill.left, 60);
    expect(timePill.height, 36);
    final time = tester.getRect(find.textContaining(' / '));
    expect(time.left, 72);
    final timeStyle = tester.widget<Text>(find.textContaining(' / ')).style!;
    expect(timeStyle.fontSize, 14);
    expect(timeStyle.fontWeight, FontWeight.w600);
    final speed = tester.getRect(find.byKey(const Key('player_speed')));
    expect(speed, Rect.fromLTWH(252, play.top, 81, 36));
    final gauge = find.descendant(
        of: find.byKey(const Key('player_speed')),
        matching: find.byWidgetPredicate(
            (w) => w is FigmaIcon && w.name == FigmaIcons.speedGauge));
    expect(tester.getRect(gauge), Rect.fromLTWH(264, play.top + 4, 28, 28));
    // 처음 기본 2x — 글자 윤곽 19×13, 왼쪽 45·세로 가운데.
    final label = find.descendant(
        of: find.byKey(const Key('player_speed')),
        matching: find.byWidgetPredicate(
            (w) => w is FigmaIcon && w.name == FigmaIcons.speedLabel(2.0)));
    expect(tester.getRect(label), Rect.fromLTWH(297, play.top + 11.5, 19, 13));
    final expand = tester.getRect(find.byKey(const Key('player_orientation')));
    expect(expand.left, 341);
    expect(expand.right, 377);

    final pill =
        tester.getRect(find.byKey(ClipPlaylistPlayerScreen.actionPillKey));
    expect(pill, const Rect.fromLTWH(88.5, 656, 216, 48));
    expect(tester.getRect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey)),
        const Rect.fromLTWH(16.5, 656, 48, 48));
    expect(tester.getRect(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey)),
        const Rect.fromLTWH(328.5, 656, 48, 48));
    // 다운로드 → 공유 → 메모 → 북마크, 36 그림 중심 x118.5/170.5/222.5/274.5.
    final icons = [
      FigmaIcons.download,
      FigmaIcons.share,
      FigmaIcons.memo,
      FigmaIcons.bookmark
    ];
    for (var i = 0; i < icons.length; i++) {
      final icon = find.descendant(
          of: find.byKey(ClipPlaylistPlayerScreen.actionPillKey),
          matching: find
              .byWidgetPredicate((w) => w is FigmaIcon && w.name == icons[i]));
      expect(tester.getCenter(icon).dx, closeTo(118.5 + 52 * i, 0.01),
          reason: icons[i]);
      expect(tester.getSize(icon), const Size(36, 36));
    }
    final strip = tester.getRect(find.byType(ClipFilmstrip));
    expect(strip.top, 716);
    expect(strip.height, 48);
    expect(tester.takeException(), isNull);
  });

  // Figma 1689:5305·1689:5647 재생바·날짜 (2026-11-04 글자·픽셀 대조).
  testWidgets('재생바는 Figma 모양 — 세로 좌우 끝까지 영상 바로 아래, 가로 여백 48',
      (tester) async {
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34));
    var bar = tester.widget<VideoSeekBar>(find.byType(VideoSeekBar));
    expect(bar.figma, FigmaSeekBar.portrait);
    var rect = tester.getRect(find.byType(VideoSeekBar));
    // 영상 아래(106 + 84 + 16:9 221.06)에 바로 붙고 화면 폭 전체.
    expect(rect.left, 0);
    expect(rect.width, 393);
    expect(rect.top, closeTo(106 + 84 + 393 * 9 / 16, 0.01));
    expect(find.text('2026. 8.28'), findsOneWidget);

    await pump(tester, const Size(852, 393));
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.pump(const Duration(milliseconds: 300));
    bar = tester.widget<VideoSeekBar>(find.byType(VideoSeekBar));
    expect(bar.figma, FigmaSeekBar.landscape);
    rect = tester.getRect(find.byType(VideoSeekBar));
    expect(rect.left, 48);
    expect(rect.right, 852 - 48);
    // 가로 날짜 알약 시각 — 세로 머리글과 같은 #626262.
    // 알약 안 두 번째 줄(첫 줄은 날짜). 시각 글자는 번역 초기화 여부에 따라
    // 달라 내용으로 찾지 않는다.
    final pillTexts = tester
        .widgetList<Text>(find.descendant(
            of: find.byKey(const Key('player_landscape_date')),
            matching: find.byType(Text)))
        .toList();
    expect(pillTexts.first.data, '2026. 8.28');
    final time = pillTexts.last;
    expect(time.style!.color, VivaColors.labelTertiary);
  });

  testWidgets('글자 2배·처음부터 버튼이 함께여도 조작줄이 넘치지 않는다', (tester) async {
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34),
        textScale: 2,
        playFromSec: const {'b': 30});
    expect(find.byKey(ClipPlaylistPlayerScreen.fromStartKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 배속 알약은 그림 글자라 81 그대로, 오른쪽 끝도 그대로.
    expect(tester.getSize(find.byKey(const Key('player_speed'))),
        const Size(81, 36));
    expect(
        tester.getRect(find.byKey(const Key('player_orientation'))).right, 377);
  });

  testWidgets('작은 화면(320)·글자 2배에서도 시간 알약이 배속 알약을 밀어내지 않는다', (tester) async {
    await pump(tester, const Size(320, 568),
        textScale: 2, playFromSec: const {'b': 30});
    expect(tester.takeException(), isNull);
    final time = tester.getRect(find.byKey(const Key('player_time_pill')));
    final speed = tester.getRect(find.byKey(const Key('player_speed')));
    expect(speed, Rect.fromLTWH(320 - 16 - 36 - 8 - 81, speed.top, 81, 36));
    expect(time.right, lessThanOrEqualTo(speed.left - 8));
  });

  testWidgets('배속 버튼을 다시 그려지기 전에 두 번 눌러도 두 단계 넘어간다', (tester) async {
    await pump(tester, const Size(393, 852));
    final speed = find.byKey(const Key('player_speed'));
    await tester.tap(speed);
    await tester.tap(speed);
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ClipPlaylistPlayerScreen)));
    expect(container.read(playerSpeedProvider), 4.0);
  });

  testWidgets('배속 버튼은 스크린리더에서도 눌린다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const Size(393, 852));
    final speed = find.byKey(const Key('player_speed'));
    final node = tester.getSemantics(speed);
    expect(node, containsSemantics(isButton: true, hasTapAction: true));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ClipPlaylistPlayerScreen)));
    expect(container.read(playerSpeedProvider), 3.0);
    handle.dispose();
  });

  testWidgets('가로 "처음부터"는 회색 알약 위 진한 글자', (tester) async {
    await pump(tester, const Size(852, 393), playFromSec: const {'b': 30});
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.pump(const Duration(milliseconds: 300));
    final style = tester
        .widget<TextButton>(find.byKey(ClipPlaylistPlayerScreen.fromStartKey))
        .style!;
    final palette = AppTheme.light.extension<GlassPalette>()!;
    expect(style.backgroundColor!.resolve({}), palette.surfaceTint);
    expect(style.foregroundColor!.resolve({}), palette.textPrimary);
    expect(tester.takeException(), isNull);
  });

  // 2026-11-04 릴리스 APK 실측: 회전·앱 복귀 때 카메라 탭이 숨김 목록을 다시
  // 불러오는 동안(loading) 화면이 방향 구독 전에 빠져나가 컨트롤러가 폐기되고,
  // 폐기 처리가 세로로 되돌렸다(가로 전환 0.4초 뒤 세로 복귀).
  testWidgets('가로로 본 뒤 숨김 목록을 다시 불러와도 가로가 유지된다', (tester) async {
    final orientations = <Object?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final visibility = StateProvider<ClipVisibilityState>(
        (_) => const ClipVisibilityState(loading: false));
    await pump(tester, const Size(852, 393), extra: [
      currentClipVisibilityProvider.overrideWith((ref) => ref.watch(visibility)),
    ]);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ClipPlaylistPlayerScreen)));
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('player_landscape_close')), findsOneWidget);
    final requestsBefore = orientations.length;

    container.read(visibility.notifier).state = const ClipVisibilityState();
    await tester.pump();
    await tester.pump();
    container.read(visibility.notifier).state =
        const ClipVisibilityState(loading: false);
    // settled(정적 큐)는 앞 테스트가 남긴 Future에 묶일 수 있어 기다리지 않고
    // 프레임만 넘긴다. 판정은 화면(가로 조작부)으로 하고, 플랫폼 기록은
    // 재로딩 동안 세로 요청이 새로 생기지 않았는지만 본다.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byKey(const Key('player_landscape_close')), findsOneWidget);
    expect(orientations.skip(requestsBefore),
        isNot(contains(['DeviceOrientation.portraitUp'])));
  });

  testWidgets('landscape: overlay chrome at Figma 941:1928 coordinates',
      (tester) async {
    await pump(tester, const Size(852, 393));
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byKey(const Key('player_landscape_close'))),
        const Rect.fromLTWH(48, 24, 44, 44));
    expect(tester.getRect(find.byKey(const Key('player_landscape_date'))),
        const Rect.fromLTWH(361, 24, 130, 48));
    expect(tester.getRect(find.byKey(ClipPlaylistPlayerScreen.actionPillKey)),
        const Rect.fromLTWH(528, 24, 276, 48));
    expect(tester.getRect(find.byKey(const Key('clip_hide_button'))).left, 540);
    final download = find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == FigmaIcons.download);
    expect(tester.getCenter(download).dx, closeTo(618, 0.01));
    expect(tester.getRect(find.byKey(const Key('player_play_pause'))).topLeft,
        const Offset(48, 285));
    expect(tester.getRect(find.byKey(const Key('player_orientation'))).topLeft,
        const Offset(768, 285));
    expect(tester.getRect(find.byKey(const Key('player_speed'))),
        const Rect.fromLTWH(679, 285, 81, 36));
    expect(tester.getRect(find.byKey(const Key('player_time_pill'))).left, 92);
    final strip = tester.getRect(find.byType(ClipFilmstrip));
    expect(strip, const Rect.fromLTWH(48, 325, 510, 48));
    // 세로 화살표는 가로에 없다.
    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsNothing);
    // 영상 좌우 바탕은 라이브 가로와 같은 회색 #626262(2026-10-21 사용자 결정).
    expect(
        tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .map((s) => s.backgroundColor),
        contains(AppTheme.landscapeBackdrop));
    // 조작부는 회색 면(#F4F4F4) 알약·원 위라 가로에서도 진한 글자(Figma
    // 1689:5647). 바닥 흐림은 같은 회색.
    final play = tester.widget<FigmaIcon>(find.descendant(
        of: find.byKey(const Key('player_play_pause')),
        matching: find.byType(FigmaIcon)));
    expect(play.color, VivaColors.labelPrimary);
    final fades = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .expand((g) => g.colors)
        .map((c) => c.withValues(alpha: 1))
        .toSet();
    expect(fades, {AppTheme.landscapeBackdrop});

    // 탭 → 컨트롤 숨김(941:2062): 영상만 남고 동일 컨트롤러 유지.
    await tester.tapAt(const Offset(426, 150));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(ClipPlaylistPlayerScreen.actionPillKey), findsNothing);
    expect(find.byKey(const Key('player_landscape_close')), findsNothing);
    await tester.tapAt(const Offset(426, 150));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(ClipPlaylistPlayerScreen.actionPillKey), findsOneWidget);

    // 더블탭 +10s 피드백 칩 (941:1928 Toast_V) — 오른쪽 절반에 잠깐.
    await tester.tapAt(const Offset(640, 150));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(640, 150));
    await tester.pump();
    final chip = find.byKey(const Key('player_seek_feedback'));
    expect(chip, findsOneWidget);
    expect(tester.getSize(chip).height, 34);
    expect(tester.getCenter(chip).dx, greaterThan(426));
    expect(find.text('+10s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(chip, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('download: white dim + 62 spinner + text, then done toast',
      (tester) async {
    final export = _Export();
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34), export: export);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == FigmaIcons.download));
    await tester.pump();
    expect(export.calls, 1);
    final overlay = find.byKey(const Key('player_download_overlay'));
    expect(overlay, findsOneWidget);
    expect(tester.getSize(overlay), const Size(393, 852));
    // Figma 1106:3659 — 스피너 62 (165.5,375), 문구 y449 (Loading 가운데 y426).
    final spinner = find.byKey(const Key('player_download_spinner'));
    expect(tester.getSize(spinner), const Size(62, 62));
    expect(tester.getCenter(spinner).dx, 196.5);
    final label = find.text('clip_download_progress');
    expect(label, findsOneWidget);
    expect(tester.getRect(label).top - tester.getRect(spinner).bottom, 12);
    // dim이 입력을 막는다 — 다운로드 버튼을 다시 눌러도 호출 없음.
    await tester.tap(
        find.byWidgetPredicate(
            (w) => w is FigmaIcon && w.name == FigmaIcons.download),
        warnIfMissed: false);
    await tester.pump();
    expect(export.calls, 1);
    export.done.complete();
    await tester.pump();
    await tester.pump();
    expect(overlay, findsNothing);
    expect(find.byKey(const Key('clip_toast')), findsOneWidget);
    expect(find.text('clip_download_done'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('clip_toast')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
