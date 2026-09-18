import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/motion_clip.dart';
import '../domain/motion_clip_page.dart';
import 'my_cage_providers.dart';
import '../domain/clip_visibility.dart';
import 'clip_visibility_providers.dart';

final clipFeedRangeProvider = StateProvider<ClipDateRange?>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return null;
});

/// Only identity changes invalidate a feed. Camera online/rotation metadata
/// updates must not replace its items with a shorter loading skeleton.
final clipFeedQueryProvider = Provider<ClipFeedQuery?>((ref) {
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final selected = ref.watch(selectedCrecamCameraProvider);
  final range = ref.watch(clipFeedRangeProvider);
  if (owner != null && selected != null) {
    return (ownerId: owner, cameraId: selected, range: range);
  }
  final id = ref.watch(camerasProvider.select((value) {
    final cameras = value.valueOrNull;
    if (cameras == null || cameras.isEmpty) return null;
    return cameras.any((camera) => camera.id == selected)
        ? selected
        : cameras.first.id;
  }));
  if (owner == null || id == null) return null;
  return (ownerId: owner, cameraId: id, range: range);
});

final clipFeedProvider = StateNotifierProvider.autoDispose
    .family<ClipFeedController, ClipFeedState, ClipFeedQuery>((ref, query) {
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final source = ref.watch(passedClipFeedSourceProvider);
  final controller = ClipFeedController((cursor) async {
    if (owner != query.ownerId) {
      return (items: <MotionClip>[], nextCursor: null, hasMore: false);
    }
    await ref.read(clipVisibilityProvider(owner!).notifier).ready();
    return loadVisibleClipPage(
      before: cursor,
      hiddenIds: () => ref.read(clipVisibilityProvider(owner)).hiddenIds,
      load: (before) => source.loadPage(query, before: before),
    );
  });
  ref.listen(currentClipVisibilityProvider, (_, visibility) {
    controller.exclude(visibility.hiddenIds);
  });
  unawaited(controller.refresh());
  return controller;
});

class ClipFeedState {
  const ClipFeedState(
      {this.items = const [],
      this.nextCursor,
      this.hasMore = true,
      this.initialLoading = true,
      this.refreshing = false,
      this.loadingMore = false,
      this.pageError});
  final List<MotionClip> items;
  final MotionClipCursor? nextCursor;
  final bool hasMore, initialLoading, refreshing, loadingMore;
  final Object? pageError;
}

typedef ClipPageLoader = Future<MotionClipPage> Function(
    MotionClipCursor? before);

class ClipFeedController extends StateNotifier<ClipFeedState> {
  ClipFeedController(this._load) : super(const ClipFeedState());
  final ClipPageLoader _load;
  int _generation = 0;
  Set<String> _hiddenIds = const {};

  void exclude(Set<String> hiddenIds) {
    if (!mounted) return;
    _hiddenIds = hiddenIds;
    final items = state.items
        .where((clip) => !hiddenIds.contains(clip.id))
        .toList(growable: false);
    if (items.length == state.items.length) return;
    state = ClipFeedState(
        items: items,
        nextCursor: state.nextCursor,
        hasMore: state.hasMore,
        initialLoading: state.initialLoading,
        refreshing: state.refreshing,
        loadingMore: state.loadingMore,
        pageError: state.pageError);
    if (items.isEmpty && state.hasMore) unawaited(loadMore());
  }

  Future<void> refresh() async {
    if (!mounted || state.refreshing) return;
    final generation = ++_generation;
    state = ClipFeedState(
        items: state.items,
        nextCursor: state.nextCursor,
        hasMore: state.hasMore,
        initialLoading: state.items.isEmpty,
        refreshing: true);
    try {
      final page = await _load(null);
      if (!mounted || generation != _generation) return;
      state = ClipFeedState(
          items: _merge(const [], page.items),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          initialLoading: false);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = ClipFeedState(
          items: state.items,
          nextCursor: state.nextCursor,
          hasMore: state.hasMore,
          initialLoading: false,
          pageError: error);
    }
  }

  Future<void> loadMore() async {
    if (!mounted ||
        state.initialLoading ||
        state.refreshing ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    final generation = _generation;
    final cursor = state.nextCursor;
    state = ClipFeedState(
        items: state.items,
        nextCursor: cursor,
        hasMore: true,
        initialLoading: false,
        loadingMore: true);
    try {
      final page = await _load(cursor);
      if (!mounted || generation != _generation) return;
      state = ClipFeedState(
          items: _merge(state.items, page.items),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          initialLoading: false);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = ClipFeedState(
          items: state.items,
          nextCursor: cursor,
          hasMore: true,
          initialLoading: false,
          pageError: error);
    }
  }

  List<MotionClip> _merge(
      List<MotionClip> previous, List<MotionClip> incoming) {
    final byId = {
      for (final clip in [...previous, ...incoming])
        if (!_hiddenIds.contains(clip.id)) clip.id: clip
    };
    final clips = byId.values.toList()
      ..sort((a, b) {
        final date = b.startedAt.compareTo(a.startedAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    return List.unmodifiable(clips);
  }
}
