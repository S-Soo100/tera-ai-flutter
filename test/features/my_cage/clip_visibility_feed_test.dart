import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';
import 'package:vivanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivanaut/features/my_cage/data/highlight_repository.dart';
import 'package:vivanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip_page.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_feed_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';

class _Visibility implements ClipVisibilityRepository {
  final hidden = <String>{};
  @override
  Future<Set<String>> hiddenClipIds(String owner) async => {...hidden};
  @override
  Future<void> hide(String owner, String clip) async {
    hidden.add(clip);
  }
}

class _Favorites implements FavoriteClipRepository {
  final rows = [
    for (final id in ['a', 'b'])
      FavoriteClip(
          clipId: id,
          cameraId: 'cam',
          startedAt: DateTime.utc(2026),
          durationSec: 10,
          filePath: '/$id.mp4',
          sizeBytes: 1,
          favoritedAt: DateTime.utc(2026),
          ownerId: 'owner')
  ];
  @override
  List<FavoriteClip> listAll() => rows;
  @override
  List<FavoriteClip> listByCamera(String camera) => rows;
  @override
  bool isFavorite(String clip) => rows.any((row) => row.clipId == clip);
  @override
  File? getLocalFile(String clip) => File('/$clip.mp4');
  @override
  FavoriteClip? getMeta(String clip) =>
      rows.where((row) => row.clipId == clip).firstOrNull;
  @override
  Future<void> add(MotionClip clip, String url) async =>
      throw StateError('Unexpected bookmark write');
  @override
  Future<String?> remove(String clip) async =>
      throw StateError('Unexpected bookmark removal');
  @override
  Future<void> syncFromCloud(MotionClipRepository repository) async {}
}

class _Highlights extends HighlightRepository {
  _Highlights()
      : super(baseUrl: 'https://unused.test', tokenProvider: () async => null);
  @override
  Future<List<NightlyHighlight>> listFeatured(
          {required String cameraId,
          int days = 30,
          String tier = 'all'}) async =>
      [
        for (final id in ['a', 'b'])
          NightlyHighlight(
              clipId: id,
              cameraId: 'cam',
              // 정책 v2: 하이라이트는 밤 구간(D 20:00~D+1 08:00 KST)만 남는다.
              startedAt: DateTime.utc(2026, 9, 15, 15),
              tier: 'featured',
              dayKey: '2026-09-15')
      ];
}

MotionClip _clip(String id) => MotionClip(
    id: id, cameraId: 'cam', startedAt: DateTime.utc(2026), durationSec: 10);
void main() {
  test(
      'hide filters bookmark and highlight projections without removing source favorite or file',
      () async {
    final favorites = _Favorites();
    final visibility = _Visibility();
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(User(
          id: 'owner',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01')),
      clipVisibilityRepositoryProvider.overrideWithValue(visibility),
      favoriteClipRepositoryProvider.overrideWithValue(favorites),
      highlightRepositoryProvider.overrideWithValue(_Highlights()),
      // 공개 게이트(D+2 08:00 KST)를 이미 지난 시각으로 고정.
      highlightClockProvider.overrideWithValue(() => DateTime.utc(2030)),
      selectedCrecamCameraProvider.overrideWith((ref) => 'cam'),
    ]);
    addTearDown(container.dispose);
    final favoritesSub = container.listen(allFavoriteClipsProvider, (_, __) {});
    final highlightsSub = container.listen(highlightGroupsProvider, (_, __) {});
    addTearDown(favoritesSub.close);
    addTearDown(highlightsSub.close);
    expect((await container.read(allFavoriteClipsProvider.future)).length, 2);
    expect(
        (await container.read(highlightGroupsProvider.future))
            .single
            .featured
            .length,
        2);
    expect(
        await container
            .read(clipVisibilityProvider('owner').notifier)
            .hide('a'),
        true);
    await container.pump();
    expect(
        (await container.read(allFavoriteClipsProvider.future))
            .map((row) => row.clipId),
        ['b']);
    expect(
        (await container.read(highlightGroupsProvider.future))
            .single
            .featured
            .map((row) => row.clipId),
        ['b']);
    expect(favorites.rows.map((row) => row.clipId), ['a', 'b']);
    expect(favorites.isFavorite('a'), true);
    expect(favorites.getLocalFile('a')?.path, '/a.mp4');
  });
  test(
      'loaded feed hides immediately and late next page cannot restore hidden ID',
      () async {
    final pending = Completer<MotionClipPage>();
    final controller = ClipFeedController((before) async => before == null
        ? (
            items: [_clip('a'), _clip('b')],
            nextCursor: (startedAt: DateTime.utc(2026), id: 'b', token: null),
            hasMore: true
          )
        : pending.future);
    addTearDown(controller.dispose);
    await controller.refresh();
    final load = controller.loadMore();
    controller.exclude({'a'});
    expect(controller.state.items.map((row) => row.id), ['b']);
    pending.complete(
        (items: [_clip('a'), _clip('c')], nextCursor: null, hasMore: false));
    await load;
    expect(controller.state.items.map((row) => row.id), ['c', 'b']);
  });
}
