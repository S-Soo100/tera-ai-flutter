import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/motion_clip_page.dart';
import 'my_cage_providers.dart';
import '../domain/clip_visibility.dart';
import 'clip_visibility_providers.dart';

typedef PlayerFeedPageLoader = Future<MotionClipPage> Function(
    MotionClipCursor? before);

/// 플레이어의 필름스트립 다음 페이지 로더. family 키에 카메라·기간·계정을
/// 모두 포함해 다른 피드 결과가 섞이지 않게 한다.
final playerFeedPageLoaderProvider = Provider.autoDispose
    .family<PlayerFeedPageLoader, ClipFeedQuery>((ref, query) {
  final source = ref.watch(passedClipFeedSourceProvider);
  return (before) async {
    await ref.read(clipVisibilityProvider(query.ownerId).notifier).ready();
    return loadVisibleClipPage(
        before: before,
        hiddenIds: () =>
            ref.read(clipVisibilityProvider(query.ownerId)).hiddenIds,
        load: (cursor) => source.loadPage(query, before: cursor));
  };
});

final playerOrientationProvider = StateNotifierProvider.autoDispose
    .family<PlayerOrientationController, bool, Object>(
        (ref, key) => PlayerOrientationController());
final playerControlsVisibleProvider =
    StateProvider.autoDispose.family<bool, Object>((ref, key) => true);
final playerSpeedProvider =
    StateProvider.autoDispose.family<double, Object>((ref, key) => 1);

/// Serialize platform requests across routes. A late landscape response cannot
/// become the final orientation after the route has already been closed.
class PlayerOrientationController extends StateNotifier<bool> {
  PlayerOrientationController() : super(false) {
    unawaited(_apply(false));
  }
  static Future<void> _queue = Future.value();
  static Future<void> get settled => _queue;
  Future<void> toggle() {
    if (!mounted) return Future.value();
    state = !state;
    return _apply(state);
  }

  Future<void> _apply(bool landscape, {bool restore = false}) {
    _queue = _queue.then((_) async {
      await SystemChrome.setPreferredOrientations(landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(
          restore
              ? SystemUiMode.manual
              : landscape
                  ? SystemUiMode.immersiveSticky
                  : SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values);
    });
    return _queue;
  }

  @override
  void dispose() {
    unawaited(_apply(false, restore: true));
    super.dispose();
  }
}

typedef PlayerPlaylistSeed = ({Object route, List<String> ids, int index});
final playerPlaylistProvider = StateProvider.autoDispose
    .family<List<String>, PlayerPlaylistSeed>((ref, seed) => seed.ids);
final playerIndexProvider = StateProvider.autoDispose
    .family<int, PlayerPlaylistSeed>((ref, seed) => seed.index);
final playerPlaylistLoadingProvider =
    StateProvider.autoDispose.family<bool, Object>((ref, key) => false);
final playerPlaylistErrorProvider =
    StateProvider.autoDispose.family<bool, Object>((ref, key) => false);
typedef PlayerFilmstripSeed = ({Object route, int initialIndex});
final playerFilmstripPreviewIndexProvider = StateProvider.autoDispose
    .family<int, PlayerFilmstripSeed>((ref, seed) => seed.initialIndex);
