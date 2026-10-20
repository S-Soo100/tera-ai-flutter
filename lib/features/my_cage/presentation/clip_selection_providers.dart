import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/video_export_service.dart';
import '../domain/clip_selection.dart';
import 'bookmark_controller.dart';
import 'clip_memo_providers.dart';
import 'clip_visibility_providers.dart';
import 'my_cage_providers.dart';

/// 선택 모드가 있는 영상 목록. 화면마다 선택이 따로다.
enum ClipSelectionScope { feed, highlights, bookmarks }

/// 화면별 선택 상태. 계정이 바뀌면 비운다.
///
/// 카메라 탭(feed)은 셸이 탭바를 숨기려고 늘 구독한다 — 하이라이트·북마크는
/// 화면을 떠나면 사라진다.
final clipSelectionProvider = StateNotifierProvider.autoDispose
    .family<ClipSelectionController, ClipSelection, ClipSelectionScope>(
        (ref, scope) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ClipSelectionController();
});

class ClipSelectionController extends StateNotifier<ClipSelection> {
  ClipSelectionController() : super(const ClipSelection());

  void enter([String? first]) => state = state.enter(first);
  void exit() => state = const ClipSelection();

  /// false면 상한이라 넣지 못했다.
  bool toggle(String id) {
    final next = state.toggle(id);
    final blocked = identical(next, state) && !state.contains(id);
    state = next;
    return !blocked;
  }

  /// true면 상한 때문에 일부만 들어갔다.
  bool setGroup(List<String> group) {
    final change = state.setGroup(group);
    state = change.selection;
    return change.limited;
  }

  bool selectAll(List<String> all) {
    final change = state.selectAll(all);
    state = change.selection;
    return change.limited;
  }

  void keepOnly(Iterable<String> ids) => state = state.keepOnly(ids);
}

enum ClipBatchKind {
  save,
  share,
  delete,
  bookmarkAdd,
  bookmarkRemove,
  memoDelete
}

/// 진행 중인 일괄 작업. [progress]는 저장·공유만(0~1).
class ClipBatchState {
  const ClipBatchState(this.kind, {this.progress});
  final ClipBatchKind kind;
  final double? progress;

  /// 사용자가 멈출 수 있는 작업(Figma [다운로드 취소]).
  bool get cancellable =>
      kind == ClipBatchKind.save || kind == ClipBatchKind.share;
}

class ClipBatchResult {
  const ClipBatchResult(
      {this.succeeded = 0,
      this.failed = const [],
      this.cancelled = false,
      this.permissionDenied = false});
  final int succeeded;
  final List<String> failed;
  final bool cancelled;
  final bool permissionDenied;
}

/// 고른 영상에 한 번에 하는 작업. 한 번에 하나만 돈다(null = 쉬는 중).
final clipBatchProvider = StateNotifierProvider.autoDispose
    .family<ClipBatchController, ClipBatchState?, ClipSelectionScope>(
        (ref, scope) => ClipBatchController(ref));

class ClipBatchController extends StateNotifier<ClipBatchState?> {
  ClipBatchController(this._ref) : super(null);
  final Ref _ref;
  ExportCancelToken? _token;

  bool get busy => state != null;

  void cancel() => _token?.cancel();

  void _progress(ClipBatchKind kind, double value) {
    if (mounted) state = ClipBatchState(kind, progress: value.clamp(0, 1));
  }

  void _finish() {
    _token = null;
    if (mounted) state = null;
  }

  /// 북마크로 이미 받아 둔 파일이 있으면 그걸, 없으면 재생 주소로 내려받는다.
  Future<({File file, bool temporary})> _fileFor(String clipId,
      ExportCancelToken token, void Function(double) onProgress) async {
    final local =
        _ref.read(favoriteClipRepositoryProvider).getLocalFile(clipId);
    if (local != null) return (file: local, temporary: false);
    final url =
        await _ref.read(motionClipRepositoryProvider).getPlaybackUrl(clipId);
    token.throwIfCancelled();
    final file = await _ref
        .read(videoExportServiceProvider)
        .downloadToTemp(clipId, url, onProgress: onProgress, cancel: token);
    return (file: file, temporary: true);
  }

  /// 사진앱 저장 — 고른 순서대로 하나씩. 취소하면 그때까지 저장한 건 남는다.
  Future<ClipBatchResult> save(List<String> ids) async {
    if (busy || ids.isEmpty) return const ClipBatchResult();
    final service = _ref.read(videoExportServiceProvider);
    const kind = ClipBatchKind.save;
    _progress(kind, 0);
    final token = _token = ExportCancelToken();
    try {
      if (!await service.ensureGalleryAccess()) {
        return const ClipBatchResult(permissionDenied: true);
      }
      var succeeded = 0;
      final failed = <String>[];
      for (var i = 0; i < ids.length; i++) {
        if (token.isCancelled) break;
        try {
          final src = await _fileFor(
              ids[i], token, (f) => _progress(kind, (i + f) / ids.length));
          token.throwIfCancelled();
          await service.putVideo(src.file);
          if (src.temporary) {
            await src.file.delete().catchError((_) => src.file);
          }
          succeeded++;
        } on ExportCancelled {
          break;
        } catch (_) {
          failed.add(ids[i]);
        }
        _progress(kind, (i + 1) / ids.length);
      }
      return ClipBatchResult(
          succeeded: succeeded, failed: failed, cancelled: token.isCancelled);
    } finally {
      _finish();
    }
  }

  /// 모두 받은 뒤 OS 공유 시트 하나로. 일부가 실패하면 받은 것만 공유한다.
  Future<ClipBatchResult> share(List<String> ids) async {
    if (busy || ids.isEmpty) return const ClipBatchResult();
    const kind = ClipBatchKind.share;
    _progress(kind, 0);
    final token = _token = ExportCancelToken();
    final files = <File>[];
    final failed = <String>[];
    try {
      for (var i = 0; i < ids.length; i++) {
        if (token.isCancelled) break;
        try {
          final src = await _fileFor(
              ids[i], token, (f) => _progress(kind, (i + f) / ids.length));
          files.add(src.file);
        } on ExportCancelled {
          break;
        } catch (_) {
          failed.add(ids[i]);
        }
        _progress(kind, (i + 1) / ids.length);
      }
    } finally {
      _finish();
    }
    if (token.isCancelled) return const ClipBatchResult(cancelled: true);
    if (files.isNotEmpty) {
      // 시트를 닫는 것은 사용자 선택이라 실패로 치지 않는다.
      try {
        await _ref.read(videoExportServiceProvider).shareFiles(files);
      } catch (_) {
        return ClipBatchResult(failed: ids);
      }
    }
    return ClipBatchResult(succeeded: files.length, failed: failed);
  }

  /// 삭제 = 이 계정 목록에서 숨김(서버 원본은 남는다, 단건 삭제와 같은 뜻).
  Future<ClipBatchResult> delete(List<String> ids) =>
      _each(ClipBatchKind.delete, ids, (id) async {
        final owner = _ref.read(clipVisibilityAccountProvider);
        if (owner == null) return false;
        return _ref.read(clipVisibilityProvider(owner).notifier).hide(id);
      });

  Future<ClipBatchResult> setBookmarked(List<String> ids, bool bookmarked) =>
      _each(
          bookmarked ? ClipBatchKind.bookmarkAdd : ClipBatchKind.bookmarkRemove,
          ids, (id) async {
        final owner = _ref.read(currentUserProvider)?.id;
        if (owner == null) return false;
        final key = (ownerId: owner, clipId: id);
        // 작업 동안 컨트롤러를 붙잡아 결과를 읽는다(autoDispose).
        final sub = _ref.listen(bookmarkControllerProvider(key), (_, __) {});
        try {
          if (sub.read().persisted == bookmarked) return true;
          final controller =
              _ref.read(bookmarkControllerProvider(key).notifier);
          controller.setDesired(bookmarked);
          await controller.settled;
          final result = sub.read();
          return result.error == null && result.persisted == bookmarked;
        } finally {
          sub.close();
        }
      });

  Future<ClipBatchResult> deleteMemos(List<String> ids) =>
      _each(ClipBatchKind.memoDelete, ids, (id) async {
        final owner = _ref.read(clipMemoAccountProvider);
        if (owner == null) return false;
        final key = (ownerId: owner, clipId: id);
        final sub = _ref.listen(clipMemoControllerProvider(key), (_, __) {});
        try {
          return await _ref
              .read(clipMemoControllerProvider(key).notifier)
              .remove();
        } finally {
          sub.close();
        }
      });

  Future<ClipBatchResult> _each(ClipBatchKind kind, List<String> ids,
      Future<bool> Function(String id) run) async {
    if (busy || ids.isEmpty) return const ClipBatchResult();
    state = ClipBatchState(kind);
    var succeeded = 0;
    final failed = <String>[];
    try {
      for (final id in ids) {
        bool ok;
        try {
          ok = await run(id);
        } catch (_) {
          ok = false;
        }
        ok ? succeeded++ : failed.add(id);
      }
      return ClipBatchResult(succeeded: succeeded, failed: failed);
    } finally {
      _finish();
    }
  }
}
