import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip_page.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmark_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/motion_clip_thumb.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hive/Supabase를 타지 않는 대역 — 즐겨찾기 없음, 로컬 파일 없음.
class _FakeFavoriteRepo implements FavoriteClipRepository {
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

MotionClip _clip(String id) => MotionClip(
      id: id,
      cameraId: 'cam-1',
      startedAt: DateTime(2026, 8, 28, 10, 21),
      durationSec: 12,
    );

Future<void> _pump(
  WidgetTester tester, {
  required String clipId,
  List<String>? playlist,
  ClipPlaybackSource source = ClipPlaybackSource.single,
  String? cameraId,
  DateTime? rangeStart,
  DateTime? rangeEndExclusive,
  MotionClipCursor? nextCursor,
  bool hasMore = false,
  PlayerFeedPageLoader? feedLoader,
  ClipVisibilityRepository? visibilityRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clipVisibilityAccountProvider
            .overrideWithValue(visibilityRepository == null ? null : 'owner-1'),
        if (visibilityRepository != null)
          clipVisibilityRepositoryProvider
              .overrideWithValue(visibilityRepository),
        currentUserProvider.overrideWithValue(
            feedLoader == null && visibilityRepository == null
                ? null
                : User(
                    id: 'owner-1',
                    appMetadata: const {},
                    userMetadata: const {},
                    aud: 'authenticated',
                    createdAt: '2026-01-01')),
        if (feedLoader != null)
          playerFeedPageLoaderProvider.overrideWith((ref, query) => feedLoader),
        if (feedLoader != null || visibilityRepository != null)
          bookmarkControllerProvider.overrideWith((ref, key) =>
              BookmarkController(initial: false, persist: (_) async {})),
        motionThumbnailFileProvider.overrideWith((ref, key) async => null),
        favoriteClipRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        motionClipProvider.overrideWith((ref, id) async => _clip(id)),
        // 네트워크 없는 테스트 — URL 발급을 실패시켜 비디오는 에러 상태 UI로
        // 정착시킨다(스켈레톤 shimmer가 남으면 pumpAndSettle이 끝나지 않는다).
        motionClipUrlProvider.overrideWith(
            (ref, id) => Future<String>.error(Exception('offline test'))),
      ],
      child: MaterialApp(
        home: ClipPlaylistPlayerScreen(
          clipId: clipId,
          playlist: playlist,
          source: source,
          cameraId: cameraId,
          rangeStart: rangeStart,
          rangeEndExclusive: rangeEndExclusive,
          nextCursor: nextCursor,
          hasMore: hasMore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _VisibilityRepository implements ClipVisibilityRepository {
  final ids = <String>{};
  bool fail = false;
  @override
  Future<Set<String>> hiddenClipIds(String account) async => {...ids};
  @override
  Future<void> hide(String account, String clip) async {
    if (fail) throw StateError('table not deployed');
    ids.add(clip);
  }
}

void main() {
  testWidgets('all hidden loaded feed clips continue into the next raw page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final repository = _VisibilityRepository()..ids.add('a');
    var calls = 0;
    await _pump(tester,
        clipId: 'a',
        playlist: ['a'],
        source: ClipPlaybackSource.feed,
        cameraId: 'cam-1',
        visibilityRepository: repository,
        hasMore: true,
        nextCursor: (startedAt: DateTime.utc(2026), id: 'a'),
        feedLoader: (_) async {
      calls++;
      return (items: [_clip('b')], nextCursor: null, hasMore: false);
    });
    expect(calls, 1);
    expect(find.text('clip_hide_empty'), findsNothing);
    expect(find.byKey(const Key('clip_hide_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete failure retains queue, retry removes only current clip',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final repository = _VisibilityRepository()..fail = true;
    await _pump(tester,
        clipId: 'a', playlist: ['a', 'b'], visibilityRepository: repository);
    await tester.tap(find.byKey(const Key('clip_hide_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'clip_hide_action'));
    await tester.pumpAndSettle();
    expect(find.text('clip_hide_failed'), findsOneWidget);
    expect(repository.ids, isEmpty);
    repository.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'clip_hide_action'));
    await tester.pumpAndSettle();
    expect(repository.ids, {'a'});
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
    expect(find.byKey(const Key('clip_hide_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'last hidden clip leaves empty player without loading saved original',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final repository = _VisibilityRepository()..ids.add('a');
    await _pump(tester, clipId: 'a', visibilityRepository: repository);
    expect(find.text('clip_hide_empty'), findsOneWidget);
    expect(find.byKey(const Key('clip_hide_button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('전체 피드는 현재 위치가 끝에서 멀면 다음 페이지를 미리 받지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final ids = [for (var i = 1; i <= 60; i++) 'c$i'];
    var calls = 0;
    await _pump(
      tester,
      clipId: 'c1',
      playlist: ids,
      source: ClipPlaybackSource.feed,
      cameraId: 'cam-1',
      nextCursor: (startedAt: DateTime(2026, 8, 28), id: 'c60'),
      hasMore: true,
      feedLoader: (cursor) async {
        calls++;
        return (items: <MotionClip>[], nextCursor: null, hasMore: false);
      },
    );

    expect(calls, 0);
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '1 / 60+');
  });

  testWidgets('전체 피드 끝에 가까우면 커서 다음 영상을 기존 목록 뒤에 붙인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final cursor = (startedAt: DateTime(2026, 8, 28), id: 'c3');
    MotionClipCursor? receivedCursor;
    var calls = 0;
    await _pump(
      tester,
      clipId: 'c3',
      playlist: const ['c1', 'c2', 'c3'],
      source: ClipPlaybackSource.feed,
      cameraId: 'cam-1',
      rangeStart: DateTime(2026, 8, 28),
      rangeEndExclusive: DateTime(2026, 8, 29),
      nextCursor: cursor,
      hasMore: true,
      feedLoader: (value) async {
        calls++;
        receivedCursor = value;
        return (
          items: [_clip('c4'), _clip('c5')],
          nextCursor: null,
          hasMore: false
        );
      },
    );

    expect(calls, 1);
    expect(receivedCursor, cursor);
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '3 / 5');
    expect(
        find.byWidgetPredicate(
            (widget) => widget is MotionClipThumb && widget.clipId == 'c5'),
        findsWidgets);
  });

  testWidgets('중간 영상은 308pt 중앙 배치와 48pt 버튼·24pt SVG를 쓴다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'c6', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);

    final pagination = find.byKey(ClipPlaylistPlayerScreen.paginationKey);
    expect(pagination, findsOneWidget);
    final current = find.byWidgetPredicate(
        (widget) => widget is MotionClipThumb && widget.clipId == 'c6');
    expect(tester.getCenter(current).dx, closeTo(393 / 2, 0.5));

    final previous = find.byKey(ClipPlaylistPlayerScreen.prevArrowKey);
    final next = find.byKey(ClipPlaylistPlayerScreen.nextArrowKey);
    final navigation =
        find.byKey(ClipPlaylistPlayerScreen.navigationActionsKey);
    final actionPill = find.byKey(ClipPlaylistPlayerScreen.actionPillKey);
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(tester.getSize(navigation), const Size(360, 48));
    expect(tester.getCenter(navigation).dx, closeTo(393 / 2, 0.5));
    expect(tester.getSize(actionPill), const Size(216, 48));
    expect(tester.getSize(previous), const Size.square(48));
    expect(tester.getSize(next), const Size.square(48));
    expect(tester.getCenter(previous).dx, closeTo(40.5, 0.5));
    expect(tester.getCenter(next).dx, closeTo(352.5, 0.5));

    final previousIcon = tester.widget<FigmaIcon>(
      find.descendant(of: previous, matching: find.byType(FigmaIcon)),
    );
    final nextIcon = tester.widget<FigmaIcon>(
      find.descendant(of: next, matching: find.byType(FigmaIcon)),
    );
    expect(previousIcon.name, FigmaIcons.arrowPrevious);
    expect(nextIcon.name, FigmaIcons.arrowNext);
    expect(previousIcon.size, 24);
    expect(nextIcon.size, 24);
    expect(previousIcon.color, const Color(0xFF3C3C3C));
    expect(nextIcon.color, const Color(0xFF3C3C3C));

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '7 / 11');
  });

  testWidgets('첫·끝 영상에서 화살표가 한쪽만 보여도 308pt 배치는 유지한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a', playlist: ['a', 'b']);

    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsNothing);
    final next = find.byKey(ClipPlaylistPlayerScreen.nextArrowKey);
    final navigation =
        find.byKey(ClipPlaylistPlayerScreen.navigationActionsKey);
    expect(next, findsOneWidget);
    expect(tester.getSize(navigation), const Size(360, 48));
    expect(tester.getCenter(navigation).dx, closeTo(393 / 2, 0.5));
    expect(tester.getCenter(next).dx, closeTo(352.5, 0.5));

    await tester.tap(next);
    await tester.pumpAndSettle();

    final previous = find.byKey(ClipPlaylistPlayerScreen.prevArrowKey);
    expect(previous, findsOneWidget);
    expect(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey), findsNothing);
    expect(tester.getSize(navigation), const Size(360, 48));
    expect(tester.getCenter(navigation).dx, closeTo(393 / 2, 0.5));
    expect(tester.getCenter(previous).dx, closeTo(40.5, 0.5));
  });

  testWidgets('재생목록 없음(단일 클립) — 페이지네이션을 그리지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');

    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
  });

  testWidgets('긴 재생목록도 가로 썸네일 스트립으로 탐색한다', (tester) async {
    // 하루치 재생목록은 쉽게 10개를 넘는다 — 숨기는 대신 같은 자리(높이 4)에
    // 진행 바로 위치를 말한다(리뷰 2026-09-04).
    await _pump(tester,
        clipId: 'c1', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
        tester
            .widget<ListView>(
                find.byKey(ClipPlaylistPlayerScreen.paginationKey))
            .scrollDirection,
        Axis.horizontal);
  });

  testWidgets('썸네일을 누르면 영상이 바뀌고 선택 항목이 중앙으로 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'c6', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);

    final target = find.byWidgetPredicate(
        (widget) => widget is MotionClipThumb && widget.clipId == 'c7');
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '7 / 11');
    expect(tester.getCenter(target).dx, closeTo(393 / 2, 0.5));
  });

  testWidgets('필름스트립 드래그 중에는 영상을 유지하고 손을 떼면 한 번 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'c6', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);

    final strip = find.byKey(ClipPlaylistPlayerScreen.paginationKey);
    final gesture = await tester.startGesture(tester.getCenter(strip));
    // 첫 이동은 Flutter의 가로 드래그 판정 거리로 소비된다. 손가락을 계속
    // 움직이는 실제 조작처럼 다음 프레임에서 한 썸네일 폭만큼 더 이동한다.
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-34, 0));
    await tester.pump();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '6 / 11');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '7 / 11');
  });

  testWidgets('위치 카운터 — "n / N"이 그려지고 이동하면 바뀐다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a', playlist: ['a', 'b', 'c']);
    expect(find.byKey(ClipPlaylistPlayerScreen.counterKey), findsOneWidget);
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '1 / 3');
    final second = find.byWidgetPredicate(
        (widget) => widget is MotionClipThumb && widget.clipId == 'b');
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '2 / 3');
  });

  testWidgets('단일 클립 — 필름스트립·카운터를 그리지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
    expect(find.byKey(ClipPlaylistPlayerScreen.counterKey), findsNothing);
    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsNothing);
    expect(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey), findsNothing);
  });

  testWidgets('상단바 — 현재 클립 startedAt으로 날짜·시각을 그린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'b', playlist: ['a', 'b']);

    expect(find.text('2026. 08. 28'), findsOneWidget);
    // 시각은 공용 formatAmPmTime(전체 문구 l10n 키) — 테스트엔
    // EasyLocalization이 없어 namedArgs 미치환 키 원문이 나온다.
    expect(find.text('time_am_fmt'), findsOneWidget);
  });
}
