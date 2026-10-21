import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_upload_queue.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmarks_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/crecam_detail_top_bar.dart';
import 'package:vivanaut/features/my_cage/domain/clip_memo.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_memo_card.dart';

/// 북마크 상세(카메라 탭 재설계 T3) 위젯 테스트.
///
/// EasyLocalization 미탑재 → tr()는 키를 그대로 돌려준다(crecam_home_test 선례).
FavoriteClip _fav(String id, DateTime startedAt, DateTime favoritedAt) =>
    FavoriteClip(
      clipId: id,
      cameraId: 'cam-1',
      startedAt: startedAt,
      durationSec: 8,
      filePath: '/tmp/$id.mp4',
      sizeBytes: 1,
      favoritedAt: favoritedAt,
      ownerId: 'u1',
    );

/// favoritedAt desc(repository 정렬 계약) 픽스처 — c1이 최신.
final _favorites = [
  _fav('c1', DateTime(2026, 8, 12, 0, 50), DateTime(2026, 9, 2)),
  _fav('c2', DateTime(2026, 8, 11, 14, 5), DateTime(2026, 9, 1)),
];

String? pushedClipId;
List<String>? pushedPlaylist;

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const BookmarksScreen()),
        GoRoute(
          path: '/crecam/player/:clipId',
          builder: (_, state) {
            pushedClipId = state.pathParameters['clipId'];
            pushedPlaylist =
                (state.extra as List?)?.whereType<String>().toList();
            return const Scaffold(body: Center(child: Text('player-screen')));
          },
        ),
        GoRoute(
          path: '/crecam/recordings/:id',
          builder: (_, state) {
            pushedClipId = 'rec-route:${state.pathParameters['id']}';
            pushedPlaylist =
                (state.extra as List?)?.whereType<String>().toList();
            return const Scaffold(body: Center(child: Text('player-screen')));
          },
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  List<FavoriteClip>? favorites,
  DateTime? dayFilter,
  List<LiveRecording>? recordings,
  LiveRecordingUploadQueue? queue,
  Map<String, String>? memos,
}) async {
  pushedClipId = null;
  pushedPlaylist = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allFavoriteClipsProvider
            .overrideWith((ref) async => favorites ?? _favorites),
        motionThumbnailFileProvider.overrideWith((ref, clipId) async => null),
        if (dayFilter != null)
          bookmarksDayFilterProvider.overrideWith((ref) => dayFilter),
        if (recordings != null) ...[
          liveRecordingsProvider.overrideWith((ref) async => recordings),
          liveRecordingBookmarksEntryProvider.overrideWith((ref) {}),
        ],
        if (queue != null)
          liveRecordingUploadQueueProvider.overrideWith((ref) => queue),
        if (memos != null) ...[
          clipMemoAccountProvider.overrideWithValue('u1'),
          clipMemoProvider
              .overrideWith((ref, key) async => switch (memos[key.clipId]) {
                    final text? => ClipMemo(
                        clipId: key.clipId,
                        text: text,
                        colorIndex: 1,
                        updatedAt: DateTime.utc(2026)),
                    null => null,
                  }),
        ],
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

LiveRecording _rec(String id, int hour, LiveRecordingUploadState state) =>
    LiveRecording(
      id: id,
      ownerId: 'u1',
      cameraId: 'cam-1',
      startedAt: DateTime(2026, 9, 3, hour),
      durationMs: 42000,
      filePath: 'live_recordings/u1/$id.mp4',
      uploadState: state,
    );

class _Queue extends LiveRecordingUploadQueue {
  _Queue()
      : super(
            ownerId: 'u1',
            local: LiveRecordingRepository(),
            api: () => throw UnimplementedError(),
            currentOwner: () => 'u1');
  final deleted = <String>[];
  @override
  Future<void> delete(LiveRecording rec) async => deleted.add(rec.id);
}

void main() {
  testWidgets('업로드 실패 카드만 길게 눌러 삭제 — 확인창 → 대기열 delete', (tester) async {
    final queue = _Queue();
    await _pump(tester,
        favorites: const [],
        queue: queue,
        recordings: [
          _rec('fail', 23, LiveRecordingUploadState.failed),
          _rec('wait', 22, LiveRecordingUploadState.pending),
        ]);
    Finder modal() => find.byKey(const Key('viva_modal_surface'));
    // 다른 상태엔 길게 누르기를 걸지 않는다(기존 동작 그대로).
    GestureDetector card(String id) => tester.widget<GestureDetector>(
        find.byKey(ValueKey('live_recording_card_$id')));
    expect(card('wait').onLongPress, isNull);
    expect(card('fail').onLongPress, isNotNull);

    await tester
        .longPress(find.byKey(const ValueKey('live_recording_card_fail')));
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(queue.deleted, isEmpty);

    await tester
        .longPress(find.byKey(const ValueKey('live_recording_card_fail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(queue.deleted, ['fail']);
  });

  testWidgets('직접 녹화 카드 업로드 표시 — 중/대기/실패, 올라간 건 없음', (tester) async {
    await _pump(tester, favorites: const [], recordings: [
      _rec('up', 23, LiveRecordingUploadState.uploading),
      _rec('wait', 22, LiveRecordingUploadState.pending),
      _rec('block', 21, LiveRecordingUploadState.blocked),
      _rec('fail', 20, LiveRecordingUploadState.failed),
      _rec('done', 19, LiveRecordingUploadState.ready),
    ]);
    Finder label(String id) =>
        find.byKey(ValueKey('live_recording_upload_$id'));
    String text(String id) => tester
        .widget<Text>(
            find.descendant(of: label(id), matching: find.byType(Text)))
        .data!;
    for (final id in ['up', 'wait', 'block', 'fail', 'done']) {
      await tester.scrollUntilVisible(
          find.byKey(ValueKey('live_recording_card_$id')), 200);
      if (id == 'done') {
        expect(label(id), findsNothing);
        continue;
      }
      expect(
          text(id),
          switch (id) {
            'up' => 'live_recording_upload_uploading',
            'fail' => 'live_recording_upload_failed',
            _ => 'live_recording_upload_waiting',
          });
    }
  });

  testWidgets('카드 렌더 — 타이틀 + 시각 헤더(자정 12시·오후 표기)', (tester) async {
    await _pump(tester);
    expect(find.text('crecam_bookmarks_title'), findsOneWidget);
    // 00:50 → 오전 12:50 (0시 = 12시 표기 엣지)
    expect(find.text('2026. 08. 12 · time_am_fmt'), findsOneWidget);
    // 14:05 → 오후 2:05
    expect(find.text('2026. 08. 11 · time_pm_fmt'), findsOneWidget);
    expect(find.byKey(CrecamDetailTopBar.calendarButtonKey), findsOneWidget);
  });

  testWidgets('빈 상태 — clip_favorites_empty', (tester) async {
    await _pump(tester, favorites: const []);
    expect(find.text('clip_favorites_empty'), findsOneWidget);
  });

  testWidgets('카드 탭 → 세로 플레이어 + 전체 북마크 재생목록(정렬 순서)', (tester) async {
    await _pump(tester);
    // 카드 면적이 커서 카드 중심이 화면 밖일 수 있다 — 헤더 텍스트를 탭한다.
    final header = find.text('2026. 08. 11 · time_pm_fmt');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(find.text('player-screen'), findsOneWidget);
    expect(pushedClipId, 'c2');
    expect(pushedPlaylist, ['c1', 'c2']);
  });

  testWidgets('날짜 필터 — 그 날짜만 + 칩 탭으로 해제', (tester) async {
    await _pump(tester, dayFilter: DateTime(2026, 8, 11));
    // 8/11 카드만 남는다.
    expect(find.byKey(const ValueKey('bookmark_card_c2')), findsOneWidget);
    expect(find.byKey(const ValueKey('bookmark_card_c1')), findsNothing);
    // 필터 칩 라벨 + 탭 → 해제(전체 복귀).
    final chip = find.byKey(CrecamDateFilterChip.chipKey);
    expect(chip, findsOneWidget);
    expect(find.text('2026. 8. 11'), findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bookmark_card_c1')), findsOneWidget);
    expect(find.byKey(CrecamDateFilterChip.chipKey), findsNothing);
  });

  testWidgets('필터 결과 0건 — 날짜 빈 문구(전체 빈 문구와 구분)', (tester) async {
    await _pump(tester, dayFilter: DateTime(2026, 1, 1));
    expect(find.text('crecam_home_empty_day'), findsOneWidget);
    expect(find.text('clip_favorites_empty'), findsNothing);
  });

  testWidgets('직접 녹화 카드에도 메모가 있으면 메모 카드(키 rec:<id>)', (tester) async {
    await _pump(tester, favorites: const [], recordings: [
      _rec('r1', 23, LiveRecordingUploadState.ready),
      _rec('r2', 22, LiveRecordingUploadState.ready),
    ], memos: {
      'rec:r1': '탈피 직전'
    });
    expect(find.byType(ClipMemoCard), findsOneWidget);
    expect(find.text('탈피 직전'), findsOneWidget);
    final card = tester.widget<ClipMemoCard>(find.byType(ClipMemoCard));
    expect(card.memoKey, (ownerId: 'u1', clipId: 'rec:r1'));
    // 메모 카드는 그 녹화 카드 안에 있다.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('live_recording_card_r1')),
            matching: find.byType(ClipMemoCard)),
        findsOneWidget);
  });

  testWidgets('재생목록은 화면 순서대로 북마크 영상과 직접 녹화를 섞는다', (tester) async {
    // c1 북마크 9/2, c2 북마크 9/1, 녹화 9/3 23시·8/31.
    await _pump(tester, recordings: [
      _rec('r1', 23, LiveRecordingUploadState.ready),
      LiveRecording(
          id: 'r0',
          ownerId: 'u1',
          cameraId: 'cam-1',
          startedAt: DateTime(2026, 8, 31, 9),
          durationMs: 42000,
          filePath: 'live_recordings/u1/r0.mp4'),
    ]);
    const mixed = ['rec:r1', 'c1', 'c2', 'rec:r0'];
    await tester.tap(find.byKey(const ValueKey('live_recording_card_r1')));
    await tester.pumpAndSettle();
    expect(pushedClipId, 'rec-route:r1');
    expect(pushedPlaylist, mixed);
  });
}
