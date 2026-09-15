import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_filmstrip.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

class _Favorite extends Fake implements FavoriteClipRepository {
  @override
  bool isFavorite(String id) => false;
  @override
  File? getLocalFile(String id) => null;
  @override
  FavoriteClip? getMeta(String id) => null;
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
  Future<void> pump(WidgetTester tester, Size size,
      {EdgeInsets padding = EdgeInsets.zero}) async {
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
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: padding),
                child: child!),
            home: const ClipPlaylistPlayerScreen(
                clipId: 'b', playlist: ['a', 'b', 'c']))));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('portrait: control row 36 at y430, action row y656, strip y716',
      (tester) async {
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34));
    // 영상은 실제 16:9(221.06)라 원본 박스 224보다 3 짧다 → 행 y427.06
    // (헤더 106 + 84 + 221.06 + 시크 16). 원본 좌표 430과의 차이는 영상
    // 비율 때문이며 그 아래 액션 행·스트립은 원본과 같다.
    final play = tester.getRect(find.byKey(const Key('player_play_pause')));
    expect(play.left, 12);
    expect(play.top, closeTo(430, 3));
    expect(play.size, const Size(36, 36));
    final speed = tester.getRect(find.byKey(const Key('player_speed')));
    expect(speed.left, 297);
    final expand = tester.getRect(find.byKey(const Key('player_orientation')));
    expect(expand.left, 345);
    final time = tester.getRect(find.textContaining(' / '));
    expect(time.left, 56);
    expect(tester.widget<Text>(find.textContaining(' / ')).style!.fontSize, 14);

    final pill = tester.getRect(find.byKey(ClipPlaylistPlayerScreen.actionPillKey));
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
          matching: find.byWidgetPredicate(
              (w) => w is FigmaIcon && w.name == icons[i]));
      expect(tester.getCenter(icon).dx, closeTo(118.5 + 52 * i, 0.01),
          reason: icons[i]);
      expect(tester.getSize(icon), const Size(36, 36));
    }
    final strip = tester.getRect(find.byType(ClipFilmstrip));
    expect(strip.top, 716);
    expect(strip.height, 48);
    expect(tester.takeException(), isNull);
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
    final strip = tester.getRect(find.byType(ClipFilmstrip));
    expect(strip, const Rect.fromLTWH(48, 325, 510, 48));
    // 세로 화살표는 가로에 없다.
    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsNothing);

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
}
