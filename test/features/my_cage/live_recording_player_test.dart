// 직접 녹화 재생 화면(2026-10-21) — 클립 세로 플레이어와 같은 틀, Riverpod 상태.
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
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_player_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_upload_queue.dart';
import 'package:vivanaut/shared/widgets/keep_screen_on.dart';
import 'package:vivanaut/shared/widgets/video_seek_bar.dart';

class _Video extends VideoPlayerPlatform {
  final plays = <int>[];
  final pauses = <int>[];
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
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async => plays.add(playerId);
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

final _rec = LiveRecording(
    id: 'r1',
    ownerId: 'u1',
    cameraId: 'cam',
    startedAt: DateTime(2026, 10, 21, 21, 5),
    durationMs: 85000,
    filePath: 'mem/r1.mp4');

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
  final deleted = <LiveRecording>[];
  @override
  Future<void> delete(LiveRecording rec) async => deleted.add(rec);
}

void main() {
  late _Video video;
  late _Queue queue;

  Future<void> pump(WidgetTester tester, {List<LiveRecording>? items}) async {
    video = _Video();
    VideoPlayerPlatform.instance = video;
    final repo = _MemRepo(items ?? [_rec]);
    queue = _Queue(repo);
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('root')),
          routes: [
            GoRoute(
                path: 'rec',
                builder: (_, __) =>
                    const LiveRecordingPlayerScreen(recordingId: 'r1')),
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
        liveRecordingRepositoryProvider.overrideWithValue(repo),
        liveRecordingUploadQueueProvider.overrideWith((ref) => queue),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/rec');
    await tester.pumpAndSettle();
  }

  testWidgets('열면 상단바(닫기·날짜·휴지통) → 영상 → 시크바 → 재생 줄, 바로 재생', (tester) async {
    await pump(tester);
    expect(find.text('2026. 10. 21'), findsOneWidget);
    expect(
        find.byKey(LiveRecordingPlayerScreen.deleteButtonKey), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byType(KeepScreenOnWhilePlaying), findsOneWidget);
    expect(find.byType(VideoSeekBar), findsOneWidget);
    expect(find.byKey(LiveRecordingPlayerScreen.playPauseKey), findsOneWidget);
    expect(find.text('0:00 / 1:25'), findsOneWidget);
    expect(video.plays, isNotEmpty);
    // 휴지통은 영상 위가 아니라 영상보다 위(상단바)에 있다 — 실기기에서 영상
    // 가운데에 겹치던 문제.
    final trash =
        tester.getRect(find.byKey(LiveRecordingPlayerScreen.deleteButtonKey));
    final videoRect =
        tester.getRect(find.byKey(LiveRecordingPlayerScreen.videoKey));
    expect(trash.bottom, lessThanOrEqualTo(videoRect.top));
    // 시크바·재생 줄은 영상 아래.
    expect(tester.getRect(find.byType(VideoSeekBar)).top,
        greaterThanOrEqualTo(videoRect.bottom));
  });

  testWidgets('재생/일시정지 버튼은 컨트롤러를 멈추고 다시 튼다', (tester) async {
    await pump(tester);
    final before = video.pauses.length;
    await tester.tap(find.byKey(LiveRecordingPlayerScreen.playPauseKey));
    await tester.pump();
    expect(video.pauses.length, before + 1);
  });

  testWidgets('삭제 — 확인창 [취소]는 남고, [삭제]면 대기열 delete 후 닫힌다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(LiveRecordingPlayerScreen.deleteButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viva_modal_surface')), findsOneWidget);
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(queue.deleted, isEmpty);
    expect(find.byType(LiveRecordingPlayerScreen), findsOneWidget);

    await tester.tap(find.byKey(LiveRecordingPlayerScreen.deleteButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(queue.deleted.single.id, 'r1');
    expect(find.byType(LiveRecordingPlayerScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('없는 녹화면 불러오기 실패 안내, 휴지통 없음', (tester) async {
    await pump(tester, items: const []);
    expect(find.text('live_recording_load_failed'), findsOneWidget);
    expect(find.byKey(LiveRecordingPlayerScreen.deleteButtonKey), findsNothing);
  });

  test('재생 화면은 setState를 쓰지 않는다(Riverpod만)', () {
    final src = File(
            'lib/features/my_cage/presentation/live_recording_player_screen.dart')
        .readAsStringSync();
    expect(src.contains('setState('), isFalse);
    expect(src.contains('StatefulWidget'), isFalse);
  });
}
