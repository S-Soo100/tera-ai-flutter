import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/video_export_service.dart';
import 'package:vivanaut/features/my_cage/domain/clip_selection.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmarks_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_selection_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_selection_widgets.dart';

List<String> _ids(int n) => [for (var i = 0; i < n; i++) 'c$i'];

class _Export extends Fake implements VideoExportService {
  bool access = true;
  final failing = <String>{};
  final saved = <String>[];
  final downloaded = <String>[];
  List<File>? shared;
  void Function()? onDownload;

  @override
  Future<bool> ensureGalleryAccess() async => access;

  @override
  Future<File> downloadToTemp(String clipId, String url,
      {void Function(double fraction)? onProgress,
      ExportCancelToken? cancel}) async {
    onDownload?.call();
    cancel?.throwIfCancelled();
    if (failing.contains(clipId)) throw const HttpException('boom');
    downloaded.add(clipId);
    onProgress?.call(0.5);
    final file = File('${Directory.systemTemp.path}/sel_test_$clipId.mp4');
    await file.writeAsString(url);
    return file;
  }

  @override
  Future<void> putVideo(File file) async =>
      saved.add(file.path.split('sel_test_').last.replaceAll('.mp4', ''));

  @override
  Future<void> shareFiles(List<File> files) async => shared = files;
}

class _Favorites extends Fake implements FavoriteClipRepository {
  @override
  File? getLocalFile(String clipId) => null;
  @override
  bool isFavorite(String clipId) => false;
}

class _Motion extends Fake implements MotionClipRepository {
  @override
  Future<String> getPlaybackUrl(String clipId) async => 'https://r2/$clipId';
}

class _Visibility implements ClipVisibilityRepository {
  final hidden = <String>{};
  final failing = <String>{};
  @override
  Future<Set<String>> hiddenClipIds(String owner) async => {...hidden};
  @override
  Future<void> hide(String owner, String clip) async {
    if (failing.contains(clip)) throw StateError('rls');
    hidden.add(clip);
  }
}

void main() {
  group('ClipSelection', () {
    test('꾹 누르기 진입은 그 영상을 고른 채 시작, 다시 누르면 빠진다', () {
      final s = const ClipSelection().enter('a');
      expect(s.active, isTrue);
      expect(s.ids, ['a']);
      expect(s.toggle('a').ids, isEmpty);
      expect(s.toggle('b').ids, ['a', 'b']);
    });

    test('20개 상한 — 21번째는 들어가지 않는다', () {
      var s = const ClipSelection().enter();
      for (final id in _ids(20)) {
        s = s.toggle(id);
      }
      expect(s.count, ClipSelection.maxCount);
      expect(identical(s.toggle('x'), s), isTrue);
    });

    test('묶음 전체 선택 — 남은 자리만 채우고, 다 골라져 있으면 모두 뺀다', () {
      var s = const ClipSelection().enter();
      for (final id in _ids(18)) {
        s = s.toggle(id);
      }
      final change = s.setGroup(['g1', 'g2', 'g3']);
      expect(change.limited, isTrue);
      expect(change.selection.ids.skip(18), ['g1', 'g2']);
      final full = const ClipSelection().enter().setGroup(['a', 'b']).selection;
      expect(groupFullySelected(full, ['a', 'b']), isTrue);
      expect(full.setGroup(['a', 'b']).selection.ids, isEmpty);
    });

    test('실패한 것만 남긴다(고른 순서 유지)', () {
      final s = const ClipSelection(active: true, ids: ['a', 'b', 'c']);
      expect(s.keepOnly({'c', 'a'}).ids, ['a', 'c']);
    });
  });

  group('ClipBatchController', () {
    late _Export export;
    late _Visibility visibility;
    late ProviderContainer container;
    const scope = ClipSelectionScope.feed;

    setUp(() {
      export = _Export();
      visibility = _Visibility();
      container = ProviderContainer(overrides: [
        videoExportServiceProvider.overrideWithValue(export),
        favoriteClipRepositoryProvider.overrideWithValue(_Favorites()),
        motionClipRepositoryProvider.overrideWithValue(_Motion()),
        clipVisibilityRepositoryProvider.overrideWithValue(visibility),
        clipVisibilityAccountProvider.overrideWithValue('owner'),
      ]);
      container.listen(clipBatchProvider(scope), (_, __) {});
    });
    tearDown(() => container.dispose());

    ClipBatchController batch() =>
        container.read(clipBatchProvider(scope).notifier);

    test('저장 — 고른 순서대로 하나씩, 실패한 것만 돌려준다', () async {
      export.failing.add('b');
      final result = await batch().save(['a', 'b', 'c']);
      expect(export.saved, ['a', 'c']);
      expect(result.succeeded, 2);
      expect(result.failed, ['b']);
      expect(result.cancelled, isFalse);
      expect(container.read(clipBatchProvider(scope)), isNull);
    });

    test('사진 권한 거절이면 내려받지 않는다', () async {
      export.access = false;
      final result = await batch().save(['a']);
      expect(result.permissionDenied, isTrue);
      expect(export.downloaded, isEmpty);
    });

    test('다운로드 취소 — 그때까지 저장한 건 남고 이후는 멈춘다', () async {
      var calls = 0;
      export.onDownload = () {
        if (++calls == 2) batch().cancel();
      };
      final result = await batch().save(['a', 'b', 'c']);
      expect(result.cancelled, isTrue);
      expect(export.saved, ['a']);
      expect(result.failed, isEmpty);
    });

    test('진행 중 상태는 저장 비율을 보여 준다', () async {
      final seen = <double?>[];
      container.listen(clipBatchProvider(scope), (_, next) {
        if (next != null) seen.add(next.progress);
      });
      await batch().save(['a', 'b']);
      expect(seen, contains(0.25));
      expect(seen.last, 1.0);
    });

    test('공유 — 받은 것만 한 번에 공유', () async {
      export.failing.add('b');
      final result = await batch().share(['a', 'b']);
      expect(export.shared, hasLength(1));
      expect(result.failed, ['b']);
    });

    test('삭제 = 계정별 숨김, 실패분 보고', () async {
      visibility.failing.add('b');
      final result = await batch().delete(['a', 'b']);
      expect(visibility.hidden, {'a'});
      expect(result.failed, ['b']);
    });
  });

  group('북마크 화면 선택 모드', () {
    FavoriteClip fav(String id, int minute) => FavoriteClip(
          clipId: id,
          cameraId: 'cam-1',
          startedAt: DateTime(2026, 8, 12, 0, minute),
          durationSec: 8,
          filePath: '/tmp/$id.mp4',
          sizeBytes: 1,
          favoritedAt: DateTime(2026, 9, 2, 0, minute),
          ownerId: 'u1',
        );

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (context, __) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => context.push('/b'),
                        child: const Text('open'))))),
        GoRoute(path: '/b', builder: (_, __) => const BookmarksScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          allFavoriteClipsProvider
              .overrideWith((ref) async => [fav('c1', 50), fav('c2', 10)]),
          motionThumbnailFileProvider.overrideWith((ref, clipId) async => null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    bool checked(WidgetTester tester, String id) => tester
        .widget<ClipSelectCheckbox>(find.descendant(
            of: find.byKey(ValueKey('clip_select_check_$id')),
            matching: find.byType(ClipSelectCheckbox)))
        .checked;

    testWidgets('선택 버튼 → 카드 탭으로 고르기 → 하단 바 → 종료', (tester) async {
      await pump(tester);
      expect(find.byKey(ClipSelectionActionBar.barKey), findsNothing);
      await tester.tap(find.byKey(const Key('clip_select_header_priority')));
      await tester.pumpAndSettle();
      expect(find.text('clip_select_count'), findsOneWidget);
      expect(find.byKey(ClipSelectionActionBar.barKey), findsOneWidget);

      await tester.tap(find.text('2026. 08. 12 · time_am_fmt').first);
      await tester.pump();
      expect(checked(tester, 'c1'), isTrue);
      expect(checked(tester, 'c2'), isFalse);

      await tester.tap(find.byKey(const Key('clip_select_header_redo')));
      await tester.pumpAndSettle();
      expect(find.text('crecam_bookmarks_title'), findsOneWidget);
      expect(find.byKey(ClipSelectionActionBar.barKey), findsNothing);
    });

    testWidgets('꾹 누르면 그 영상이 골라진 채 시작', (tester) async {
      await pump(tester);
      await tester.longPress(find.byKey(const ValueKey('bookmark_card_c2')));
      await tester.pumpAndSettle();
      expect(checked(tester, 'c2'), isTrue);
      expect(checked(tester, 'c1'), isFalse);
    });

    testWidgets('고른 채 뒤로 → 이탈 확인, 아니요면 남는다', (tester) async {
      await pump(tester);
      await tester.longPress(find.byKey(const ValueKey('bookmark_card_c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('clip_select_leave_confirm'), findsOneWidget);
      await tester.tap(find.text('clip_select_leave_stay'));
      await tester.pumpAndSettle();
      expect(find.text('clip_select_count'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clip_select_leave_ok')));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });
}
