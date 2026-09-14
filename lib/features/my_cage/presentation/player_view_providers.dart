import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
