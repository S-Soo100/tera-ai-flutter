// 직접 녹화 재생(2026-10-21) — 일반 영상과 같은 세로 플레이어
// (`ClipPlaylistPlayerScreen`). 보관함 순서로 북마크 영상과 섞여 넘어간다.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/clip_memo_repository.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/video_export_service.dart';
import 'package:vivanaut/features/my_cage/domain/clip_memo.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/player_entry.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmark_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_actions.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_upload_queue.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_memo_editor.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'package:vivanaut/shared/widgets/keep_screen_on.dart';
import 'package:vivanaut/shared/widgets/video_seek_bar.dart';

class _Video extends VideoPlayerPlatform {
  var _next = 0;
  final speeds = <double>[];
  final pauses = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => ++_next;
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    late StreamController<VideoEvent> c;
    c = StreamController(
        onListen: () => c.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 85),
            size: const Size(1280, 960))),
        onCancel: () async {});
    return c.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      speeds.add(speed);
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async => pauses.add(playerId);
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF000000));
}

LiveRecording _recording(String id) => LiveRecording(
    id: id,
    ownerId: 'u1',
    cameraId: 'cam',
    startedAt: DateTime(2026, 10, 21, 21, 5),
    durationMs: 85000,
    filePath: 'mem/$id.mp4');

MotionClip _clip(String id) => MotionClip(
    id: id,
    cameraId: 'cam',
    startedAt: DateTime(2026, 8, 28, 10, 21),
    durationSec: 12);

class _MemRepo extends LiveRecordingRepository {
  _MemRepo(this.items);
  final List<LiveRecording> items;
  @override
  Future<String> resolve(String rel) async => '/mem/$rel';
  @override
  Future<List<LiveRecording>> list(String ownerId) async => items;
}

class _Queue extends LiveRecordingUploadQueue {
  _Queue(LiveRecordingRepository repo)
      : super(
            ownerId: 'u1',
            local: repo,
            api: () => throw UnimplementedError(),
            currentOwner: () => 'u1');
  final deleted = <String>[];
  @override
  Future<void> delete(LiveRecording rec) async => deleted.add(rec.id);
}

class _Memos implements ClipMemoRepository {
  final memos = <String, ClipMemo>{};
  @override
  Future<ClipMemo?> read(String account, String clip) async =>
      memos['$account/$clip'];
  @override
  Future<void> save(String account, String clip, String text) async =>
      memos['$account/$clip'] = ClipMemo(
          clipId: clip,
          text: text,
          colorIndex: 2,
          updatedAt: DateTime.utc(2026));
  @override
  Future<void> remove(String account, String clip) async =>
      memos.remove('$account/$clip');
}

class _Export extends VideoExportService {
  final saved = <String>[];
  final shared = <String>[];
  @override
  Future<void> saveToGallery(String clipId,
          {File? localFile, String? presignedUrl}) async =>
      saved.add(localFile!.path);
  @override
  Future<void> share(String clipId,
          {File? localFile, String? presignedUrl}) async =>
      shared.add(localFile!.path);
}

class _NoFavorites implements FavoriteClipRepository {
  @override
  bool isFavorite(String clipId) => false;
  @override
  File? getLocalFile(String clipId) => null;
  @override
  FavoriteClip? getMeta(String clipId) => null;
  @override
  List<FavoriteClip> listByCamera(String cameraId) => const [];
  @override
  List<FavoriteClip> listAll() => const [];
  @override
  Future<void> add(MotionClip clip, String presignedUrl) async {}
  @override
  Future<String?> remove(String clipId) async => null;
  @override
  Future<void> syncFromCloud(MotionClipRepository motionRepo) async {}
}

void main() {
  late _Video video;
  late _Queue queue;
  late _Memos memos;
  late _Export export;
  final bookmarkWrites = <bool>[];

  /// [playlist]는 보관함 순서의 항목 키. 첫 화면은 녹화 [open].
  Future<void> pump(WidgetTester tester,
      {String open = 'r1', List<String>? playlist}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    video = _Video();
    VideoPlayerPlatform.instance = video;
    final items = [_recording('r1'), _recording('r2')];
    final repo = _MemRepo(items);
    queue = _Queue(repo);
    memos = _Memos();
    export = _Export();
    bookmarkWrites.clear();
    // 앱 라우터의 `/crecam/recordings/:id`와 같은 조립.
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('root')),
          routes: [
            GoRoute(
                path: 'rec',
                builder: (_, state) => ClipPlaylistPlayerScreen(
                    clipId: RecordingEntry(open).key,
                    playlist: (state.extra as List?)?.cast<String>())),
          ]),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(User(
            id: 'u1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '2026-01-01')),
        clipVisibilityAccountProvider.overrideWithValue(null),
        liveRecordingRepositoryProvider.overrideWithValue(repo),
        liveRecordingUploadQueueProvider.overrideWith((ref) => queue),
        liveRecordingsProvider.overrideWith((ref) async => items),
        liveRecordingThumbFileProvider.overrideWith((ref, rel) async => null),
        clipMemoRepositoryProvider.overrideWith((ref) async => memos),
        videoExportServiceProvider.overrideWithValue(export),
        favoriteClipRepositoryProvider.overrideWithValue(_NoFavorites()),
        motionThumbnailFileProvider.overrideWith((ref, key) async => null),
        motionClipProvider.overrideWith((ref, id) async => _clip(id)),
        motionClipUrlProvider.overrideWith(
            (ref, id) => Future<String>.error(Exception('offline test'))),
        bookmarkControllerProvider.overrideWith((ref, key) =>
            BookmarkController(
                initial: true, persist: (v) async => bookmarkWrites.add(v))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/rec', extra: playlist);
    await tester.pumpAndSettle();
  }

  String bookmarkAsset(WidgetTester tester) => tester
      .widget<FigmaIcon>(find.descendant(
          of: find.byKey(ClipPlaylistPlayerScreen.bookmarkKey),
          matching: find.byType(FigmaIcon)))
      .name;

  testWidgets('일반 영상 플레이어와 같은 틀 — 알약 4버튼·화살표·필름스트립·2X·가로', (tester) async {
    await pump(tester, open: 'r1', playlist: ['c1', 'rec:r1', 'c2']);
    expect(find.text('2026. 10. 21'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byType(KeepScreenOnWhilePlaying), findsOneWidget);
    expect(find.byType(VideoSeekBar), findsOneWidget);
    final pill = find.byKey(ClipPlaylistPlayerScreen.actionPillKey);
    expect(pill, findsOneWidget);
    for (final tip in ['clip_save', 'clip_share', 'clip_memo_add']) {
      expect(find.descendant(of: pill, matching: find.byTooltip(tip)),
          findsOneWidget,
          reason: tip);
    }
    expect(
        find.descendant(
            of: pill,
            matching: find.byKey(ClipPlaylistPlayerScreen.bookmarkKey)),
        findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey), findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsOneWidget);
    expect(find.byKey(const Key('player_speed')), findsOneWidget);
    expect(find.byKey(const Key('player_orientation')), findsOneWidget);
    // 휴지통은 숨기기가 아니라 녹화 삭제.
    expect(find.byTooltip('live_recording_delete_confirm'), findsOneWidget);
  });

  testWidgets('2X는 배속을 순환하고, 가로 버튼은 가로 화면으로 바꾼다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('player_speed')));
    await tester.pump();
    expect(video.speeds.last, 1.2);
    await tester.tap(find.byKey(const Key('player_orientation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player_landscape_close')), findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.bookmarkKey), findsOneWidget);
  });

  testWidgets('다운로드·공유는 폰 녹화 파일을 그대로 넘긴다', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('clip_save'));
    await tester.pumpAndSettle();
    expect(export.saved, ['/mem/mem/r1.mp4']);
    await tester.tap(find.byTooltip('clip_share'));
    await tester.pumpAndSettle();
    expect(export.shared, ['/mem/mem/r1.mp4']);
    await tester.pump(const Duration(seconds: 3)); // 완료 토스트 정리
  });

  testWidgets('북마크는 늘 켜진 모양이고 눌러도 아무 일 없다', (tester) async {
    await pump(tester);
    expect(bookmarkAsset(tester), FigmaIcons.bookmarkFilled);
    expect(
        find.descendant(
            of: find.byKey(ClipPlaylistPlayerScreen.bookmarkKey),
            matching: find.byType(InkWell)),
        findsNothing);
    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.bookmarkKey));
    await tester.pumpAndSettle();
    expect(bookmarkAsset(tester), FigmaIcons.bookmarkFilled);
    expect(bookmarkWrites, isEmpty);
    expect(queue.deleted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('메모 — 열어 쓰고 저장하면 rec:<id> 키, 다시 열면 그 메모를 고친다', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('clip_memo_add'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipMemoEditor), findsOneWidget);
    await tester.enterText(find.byKey(const Key('clip_memo_input')), '첫 탈피');
    await tester.pump();
    await tester.tap(find.text('clip_memo_save'));
    await tester.pumpAndSettle();
    expect(memos.memos.keys, ['u1/rec:r1']);
    expect(memos.memos['u1/rec:r1']!.text, '첫 탈피');

    // 메모가 생기면 채워진 아이콘 + "메모 수정".
    await tester.tap(find.byTooltip('clip_memo_edit'));
    await tester.pumpAndSettle();
    expect(find.text('첫 탈피'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('clip_memo_input')), '두 번째 탈피');
    await tester.pump();
    await tester.tap(find.text('clip_memo_save'));
    await tester.pumpAndSettle();
    expect(memos.memos['u1/rec:r1']!.text, '두 번째 탈피');
  });

  testWidgets('삭제 — 확인창 [취소]는 남고, [삭제]면 대기열 delete + 메모 삭제 후 닫힌다',
      (tester) async {
    await pump(tester);
    await memos.save('u1', 'rec:r1', '지울 메모');
    await memos.save('u1', 'c1', '남길 메모');
    await tester.tap(find.byKey(const Key('clip_hide_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(queue.deleted, isEmpty);
    expect(find.byType(ClipPlaylistPlayerScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('clip_hide_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(queue.deleted, ['r1']);
    expect(memos.memos.keys, ['u1/c1']);
    expect(find.byType(ClipPlaylistPlayerScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('섞인 목록에서 삭제하면 닫지 않고 다음 항목으로 넘어간다', (tester) async {
    await pump(tester, open: 'r1', playlist: ['rec:r1', 'c1']);
    await tester.tap(find.byKey(const Key('clip_hide_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(queue.deleted, ['r1']);
    expect(find.byType(ClipPlaylistPlayerScreen), findsOneWidget);
    expect(find.text('2026. 08. 28'), findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
    // 일반 영상으로 돌아오면 휴지통은 다시 숨기기, 북마크는 원래 토글.
    expect(find.byTooltip('clip_hide_action'), findsOneWidget);
    expect(find.byTooltip('clip_favorite_remove'), findsOneWidget);
  });

  testWidgets('이전/다음 화살표가 녹화 ↔ 일반 영상을 오간다', (tester) async {
    await pump(tester, open: 'r1', playlist: ['c1', 'rec:r1', 'rec:r2', 'c2']);
    expect(find.text('2026. 10. 21'), findsOneWidget);

    // 녹화 → 이전 = 일반 영상 c1(날짜·북마크 토글이 일반 영상 것).
    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey));
    await tester.pumpAndSettle();
    expect(find.text('2026. 08. 28'), findsOneWidget);
    expect(find.byTooltip('clip_favorite_remove'), findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsNothing);

    // 일반 영상 → 다음 = 녹화 r1(폰 파일로 재생, 북마크 고정).
    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey));
    await tester.pumpAndSettle();
    expect(find.text('2026. 10. 21'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(bookmarkAsset(tester), FigmaIcons.bookmarkFilled);
    expect(find.byTooltip('clip_favorite_remove'), findsNothing);

    // 녹화 → 녹화 → 일반 영상 c2(마지막).
    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey));
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsOneWidget);
    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey));
    await tester.pumpAndSettle();
    expect(find.text('2026. 08. 28'), findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey), findsNothing);
  });

  testWidgets('없는 녹화면 불러오기 실패 안내', (tester) async {
    await pump(tester, open: 'gone');
    expect(find.text('live_recording_load_failed'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
  });

  test('항목 키 — 녹화는 rec: 접두, 그 밖은 clip id', () {
    expect(const RecordingEntry('r1').key, 'rec:r1');
    expect(PlayerEntry.parse('rec:r1'),
        isA<RecordingEntry>().having((e) => e.recordingId, 'id', 'r1'));
    expect(PlayerEntry.parse('6b1f-uuid'),
        isA<ClipEntry>().having((e) => e.clipId, 'id', '6b1f-uuid'));
    expect(PlayerEntry.parse('rec:'), isA<ClipEntry>());
  });
}
