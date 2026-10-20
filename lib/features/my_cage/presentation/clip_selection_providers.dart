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

  /// 목록이 바뀌면(기간·날짜 필터) 선택만 비운다 — 안 보이는 영상이 골라진 채
  /// 남아 삭제·저장에 끼지 않게. 선택 모드는 유지.
  void clearIds() {
    if (state.ids.isNotEmpty) state = ClipSelection(active: state.active);
  }

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

/// 진행 중인 일괄 작업. [progress]는 저장·공유·북마크(0~1) — 오래 걸릴 수 있는
/// 작업이라 진행률과 [취소]를 보여 준다. 삭제·메모 삭제는 짧아 스피너만.
class ClipBatchState {
  const ClipBatchState(this.kind, {this.progress});
  final ClipBatchKind kind;
  final double? progress;

  /// 사용자가 멈출 수 있는 작업(Figma [다운로드 취소]).
  bool get cancellable => progress != null;
}

class ClipBatchResult {
  const ClipBatchResult(
      {this.succeeded = 0,
      this.failed = const [],
      this.remaining = const [],
      this.cancelled = false,
      this.permissionDenied = false,
      this.ignored = false});

  /// 다른 작업이 돌고 있어 시작하지 않았다(연타). 성공으로 읽으면 안 된다.
  const ClipBatchResult.ignored() : this(ignored: true);

  final int succeeded;
  final List<String> failed;

  /// 취소로 손대지 못한 영상.
  final List<String> remaining;
  final bool cancelled;
  final bool permissionDenied;
  final bool ignored;
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

  /// 시작 — 이미 돌고 있으면 null(연타 무시). 상태를 **동기로** 세워 같은
  /// 프레임의 두 번째 탭도 막는다.
  ExportCancelToken? _start(ClipBatchKind kind, {bool progress = true}) {
    if (busy) return null;
    state = progress ? ClipBatchState(kind, progress: 0) : ClipBatchState(kind);
    return _token = ExportCancelToken();
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
  /// 내려받은 임시 파일은 성공·실패·취소 모두 지운다.
  Future<ClipBatchResult> save(List<String> ids) async {
    if (ids.isEmpty) return const ClipBatchResult();
    const kind = ClipBatchKind.save;
    final token = _start(kind);
    if (token == null) return const ClipBatchResult.ignored();
    final service = _ref.read(videoExportServiceProvider);
    try {
      // 지난 공유가 남긴 임시 파일 — 공유 앱이 읽는 중일 수 있어 다음 작업 때 지운다.
      await service.clearTemp();
      if (!await service.ensureGalleryAccess()) {
        return const ClipBatchResult(permissionDenied: true);
      }
      var succeeded = 0;
      final failed = <String>[];
      var i = 0;
      for (; i < ids.length; i++) {
        if (token.isCancelled) break;
        File? temp;
        try {
          final src = await _fileFor(
              ids[i], token, (f) => _progress(kind, (i + f) / ids.length));
          if (src.temporary) temp = src.file;
          token.throwIfCancelled();
          await service.putVideo(src.file);
          succeeded++;
        } on ExportCancelled {
          break;
        } catch (_) {
          failed.add(ids[i]);
        } finally {
          if (temp != null) {
            await temp.delete().catchError((_) => temp!);
          }
        }
        _progress(kind, (i + 1) / ids.length);
      }
      return ClipBatchResult(
          succeeded: succeeded,
          failed: failed,
          remaining: token.isCancelled ? ids.sublist(i) : const [],
          cancelled: token.isCancelled);
    } finally {
      _finish();
    }
  }

  /// 모두 받은 뒤 OS 공유 시트 하나로. 일부가 실패하면 받은 것만 공유한다.
  Future<ClipBatchResult> share(List<String> ids) async {
    if (ids.isEmpty) return const ClipBatchResult();
    const kind = ClipBatchKind.share;
    final token = _start(kind);
    if (token == null) return const ClipBatchResult.ignored();
    final service = _ref.read(videoExportServiceProvider);
    final files = <File>[];
    final failed = <String>[];
    try {
      await service.clearTemp();
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
    if (token.isCancelled) {
      await service.clearTemp();
      return const ClipBatchResult(cancelled: true);
    }
    if (files.isNotEmpty) {
      // 시트를 닫는 것은 사용자 선택이라 실패로 치지 않는다. 임시 파일은 받는
      // 앱이 아직 읽을 수 있어 여기서 지우지 않고 다음 작업 시작 때 지운다.
      try {
        await service.shareFiles(files);
      } catch (_) {
        return ClipBatchResult(failed: ids);
      }
    }
    return ClipBatchResult(succeeded: files.length, failed: failed);
  }

  /// 삭제 = 이 계정 목록에서 숨김(서버 원본은 남는다, 단건 삭제와 같은 뜻).
  Future<ClipBatchResult> delete(List<String> ids) =>
      _each(ClipBatchKind.delete, ids, progress: false, (id) async {
        final owner = _ref.read(clipVisibilityAccountProvider);
        if (owner == null) return false;
        return _ref.read(clipVisibilityProvider(owner).notifier).hide(id);
      });

  /// 북마크 하기는 영상마다 기기에 내려받는다(오프라인 재생) — 오래 걸릴 수
  /// 있어 진행률·취소를 준다. 취소는 지금 영상을 끝낸 뒤 멈춘다.
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
      _each(ClipBatchKind.memoDelete, ids, progress: false, (id) async {
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
      Future<bool> Function(String id) run,
      {bool progress = true}) async {
    if (ids.isEmpty) return const ClipBatchResult();
    final token = _start(kind, progress: progress);
    if (token == null) return const ClipBatchResult.ignored();
    var succeeded = 0;
    final failed = <String>[];
    var i = 0;
    try {
      for (; i < ids.length; i++) {
        if (token.isCancelled) break;
        bool ok;
        try {
          ok = await run(ids[i]);
        } catch (_) {
          ok = false;
        }
        ok ? succeeded++ : failed.add(ids[i]);
        if (progress) _progress(kind, (i + 1) / ids.length);
      }
      return ClipBatchResult(
          succeeded: succeeded,
          failed: failed,
          remaining: token.isCancelled ? ids.sublist(i) : const [],
          cancelled: token.isCancelled);
    } finally {
      _finish();
    }
  }
}
