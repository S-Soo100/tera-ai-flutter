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
import 'package:vivanaut/shared/widgets/figma_icon.dart';

class _Favorite extends Fake implements FavoriteClipRepository {
  _Favorite({this.favorite = false});
  final bool favorite;
  @override
  bool isFavorite(String id) => favorite;
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

/// SVG의 `viewBox` 가로 = Figma export 프레임.
double _frameOf(String name) {
  final svg = File('assets/icons/$name.svg').readAsStringSync();
  final vb = RegExp(r'viewBox="([^"]+)"').firstMatch(svg);
  expect(vb, isNotNull, reason: '$name.svg에 viewBox가 없다');
  return double.parse(vb!.group(1)!.trim().split(RegExp(r'\s+'))[2]);
}

/// 아이콘은 **export 프레임 크기로 그린다.**
///
/// 프레임에는 이미 디자인이 정한 여백이 들어 있어서, 24 프레임 export를 36
/// 자리에 그리면 글리프만 1.5배로 커지고 44 프레임 export를 24로 그리면 절반
/// 크기로 쪼그라든다. 같은 줄에 선 버튼들 사이에서 그 차이가 바로 보인다.
/// (2026-09-21 실기기 신고: 북마크를 누르면 아이콘이 확 커지고 휴지통만 작다.)
void main() {
  Future<void> pump(WidgetTester tester, Size size,
      {EdgeInsets padding = EdgeInsets.zero, bool favorite = false}) async {
    VideoPlayerPlatform.instance = _Video();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          favoriteClipRepositoryProvider
              .overrideWithValue(_Favorite(favorite: favorite)),
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

  void expectFramesMatch(WidgetTester tester) {
    final icons = tester.widgetList<FigmaIcon>(find.byType(FigmaIcon));
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      expect(icon.size, _frameOf(icon.name),
          reason: '${icon.name}: export 프레임과 다른 크기로 그린다');
    }
  }

  testWidgets('세로 플레이어의 아이콘은 export 프레임 크기로 그린다', (tester) async {
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34));
    expectFramesMatch(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 플레이어의 아이콘도 export 프레임 크기로 그린다', (tester) async {
    await pump(tester, const Size(852, 393));
    expectFramesMatch(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('북마크한 영상의 아이콘도 export 프레임 크기로 그린다', (tester) async {
    await pump(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 62, bottom: 34), favorite: true);
    expect(
        find.byWidgetPredicate(
            (w) => w is FigmaIcon && w.name == FigmaIcons.bookmarkCheck),
        findsWidgets);
    expectFramesMatch(tester);
    expect(tester.takeException(), isNull);
  });
}
