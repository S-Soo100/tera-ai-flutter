import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/presentation/auth_providers.dart';
import 'my_cage_providers.dart';

typedef BookmarkKey = ({String ownerId, String clipId});
final bookmarkControllerProvider = StateNotifierProvider.autoDispose
    .family<BookmarkController, BookmarkState, BookmarkKey>((ref, key) {
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final repository = ref.watch(favoriteClipRepositoryProvider);
  final motion = ref.watch(motionClipRepositoryProvider);
  var active = true;
  ref.onDispose(() => active = false);
  void Function()? releaseJob;
  return BookmarkController(
      onActivityChanged: (running) {
        if (running) {
          final link = ref.keepAlive();
          releaseJob = link.close;
        } else {
          releaseJob?.call();
          releaseJob = null;
        }
      },
      initial: owner == key.ownerId && repository.isFavorite(key.clipId),
      persist: (desired) async {
        if (!active || owner != key.ownerId) {
          throw StateError('Bookmark session changed');
        }
        String? cameraId;
        if (desired) {
          final clip = await motion.getById(key.clipId);
          if (!active) return;
          if (clip == null) throw StateError('Clip unavailable');
          final url = await motion.getPlaybackUrl(key.clipId);
          if (!active) return;
          await repository.add(clip, url);
          cameraId = clip.cameraId;
        } else {
          cameraId = await repository.remove(key.clipId);
        }
        if (!active) return;
        ref.invalidate(isFavoriteProvider(key.clipId));
        if (cameraId != null) ref.invalidate(favoriteClipsProvider(cameraId));
        ref.invalidate(allFavoriteClipsProvider);
      });
});

class BookmarkState {
  const BookmarkState(
      {required this.desired,
      required this.persisted,
      this.saving = false,
      this.error});
  final bool desired, persisted, saving;
  final Object? error;
}

/// One writer per clip, always converging to the last tap rather than the last
/// network response. The route may disappear while the provider keeps the job.
class BookmarkController extends StateNotifier<BookmarkState> {
  BookmarkController(
      {required bool initial,
      required Future<void> Function(bool) persist,
      void Function(bool)? onActivityChanged})
      : _persist = persist,
        _onActivityChanged = onActivityChanged,
        super(BookmarkState(desired: initial, persisted: initial));
  final Future<void> Function(bool) _persist;
  final void Function(bool)? _onActivityChanged;
  Future<void> _job = Future.value();
  bool _running = false;
  bool? _failedIntent;
  Future<void> get settled => _job;

  void setDesired(bool desired) {
    if (!mounted) return;
    _failedIntent = null;
    state = BookmarkState(
        desired: desired, persisted: state.persisted, saving: true);
    if (!_running) {
      _running = true;
      _onActivityChanged?.call(true);
      _job = _drain();
    }
  }

  void retry() {
    if (_failedIntent case final value?) setDesired(value);
  }

  Future<void> _drain() async {
    try {
      while (mounted && state.desired != state.persisted) {
        final target = state.desired;
        Object? failure;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await _persist(target);
            failure = null;
            break;
          } catch (error) {
            failure = error;
            if (!mounted || state.desired != target) break;
            final transient = error is SocketException ||
                error is TimeoutException ||
                error is http.ClientException;
            if (!transient || attempt == 2) break;
            await Future<void>.delayed(Duration(seconds: attempt == 0 ? 1 : 3));
          }
        }
        if (!mounted) return;
        if (failure != null) {
          if (state.desired != target) continue;
          _failedIntent = target;
          state = BookmarkState(
              desired: state.persisted,
              persisted: state.persisted,
              error: failure);
          return;
        }
        state = BookmarkState(
            desired: state.desired,
            persisted: target,
            saving: state.desired != target);
      }
      if (mounted) {
        state =
            BookmarkState(desired: state.desired, persisted: state.persisted);
      }
    } finally {
      _running = false;
      _onActivityChanged?.call(false);
    }
  }
}
