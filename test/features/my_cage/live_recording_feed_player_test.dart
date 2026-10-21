// 플레이어 — 서버에만 있는 녹화는 서버 URL로 재생, 카메라 탭에서 열면 다음
// 페이지에도 직접 녹화가 시각순으로 끼워진다(2026-10-21 F단계).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/recording_item.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmark_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_upload_queue.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/recording_library_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_filmstrip.dart';

class _Video extends VideoPlayerPlatform {
  var _next = 0;
  final sources = <String?>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource.uri);
    return ++_next;
  }

  @override
  Future<void> dispose(int playerId) async {}
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    late StreamController<VideoEvent> c;
    c = StreamController(
        onListen: () => c.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 30),
            size: const Size(1280, 960))),
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
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF000000));
}

class _NoFavorites extends Fake implements FavoriteClipRepository {
  @override
  bool isFavorite(String clipId) => false;
  @override
  File? getLocalFile(String clipId) => null;
  @override
  FavoriteClip? getMeta(String clipId) => null;
}

MotionClip _clip(String id, int hour) => MotionClip(
    id: id,
    cameraId: 'cam',
    startedAt: DateTime(2026, 10, 21, hour),
    durationSec: 8);

RecordingItem _server(String id, int hour) =>
    RecordingItem.server(ServerLiveRecording(
        id: id,
        cameraId: 'cam',
        startedAt: DateTime(2026, 10, 21, hour),
        durationMs: 30000,
        hasThumbnail: false));

Future<_Video> _pump(WidgetTester tester,
    {required ClipPlaylistPlayerScreen screen,
    required List<RecordingItem> recordings,
    PlayerFeedPageLoader? feedLoader}) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final video = _Video();
  VideoPlayerPlatform.instance = video;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(User(
          id: 'u1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01')),
      clipVisibilityAccountProvider.overrideWithValue(null),
      clipMemoProvider.overrideWith((ref, key) async => null),
      liveRecordingUploadQueueProvider.overrideWith((ref) =>
          LiveRecordingUploadQueue(
              ownerId: null,
              local: LiveRecordingRepository(),
              api: () => throw UnimplementedError(),
              currentOwner: () => null)),
      recordingLibraryProvider.overrideWith((ref) => AsyncData(recordings)),
      serverRecordingUrlProvider
          .overrideWith((ref, id) async => 'https://r2.test/rec/$id.mp4'),
      motionClipUrlProvider
          .overrideWith((ref, id) async => 'https://r2.test/clip/$id.mp4'),
      motionClipProvider.overrideWith((ref, id) async => null),
      motionThumbnailFileProvider.overrideWith((ref, key) async => null),
      favoriteClipRepositoryProvider.overrideWithValue(_NoFavorites()),
      bookmarkControllerProvider.overrideWith((ref, key) =>
          BookmarkController(initial: false, persist: (_) async {})),
      if (feedLoader != null)
        playerFeedPageLoaderProvider.overrideWith((ref, query) => feedLoader),
    ],
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
  return video;
}

void main() {
  testWidgets('서버에만 있는 녹화는 서버 재생 URL로 연다 — 날짜는 서버 녹화 시각', (tester) async {
    final video = await _pump(tester,
        screen: const ClipPlaylistPlayerScreen(
            clipId: 'rec:srv:s1', playlist: ['c1', 'rec:srv:s1']),
        recordings: [_server('s1', 21)]);
    expect(video.sources, ['https://r2.test/rec/s1.mp4']);
    expect(find.text('2026. 10. 21'), findsOneWidget);
    // 휴지통은 녹화 삭제 뜻.
    expect(find.byTooltip('live_recording_delete_confirm'), findsOneWidget);
  });

  testWidgets('카메라 탭에서 열면 다음 페이지에 그 경계의 녹화를 시각순으로 끼운다', (tester) async {
    final cursors = <DateTime?>[];
    await _pump(tester,
        screen: ClipPlaylistPlayerScreen(
          clipId: 'c1',
          playlist: const ['c1', 'rec:srv:new'],
          source: ClipPlaybackSource.feed,
          cameraId: 'cam',
          hasMore: true,
          nextCursor: (
            startedAt: DateTime(2026, 10, 21, 18),
            id: 'c1',
            token: null
          ),
          feedFloor: DateTime(2026, 10, 21, 18),
        ),
        recordings: [
          _server('new', 19),
          _server('mid', 12),
          _server('old', 2),
        ], feedLoader: (cursor) async {
      cursors.add(cursor?.startedAt);
      return (
        items: [_clip('c2', 15), _clip('c3', 10)],
        nextCursor: null,
        hasMore: false,
      );
    });
    expect(cursors, [DateTime(2026, 10, 21, 18)]);
    final strip = tester.widget<ClipFilmstrip>(find.byType(ClipFilmstrip));
    expect(strip.clipIds,
        ['c1', 'rec:srv:new', 'c2', 'rec:srv:mid', 'c3', 'rec:srv:old']);
  });
}
