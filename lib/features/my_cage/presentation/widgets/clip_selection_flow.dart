import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/viva_modal.dart';
import '../../domain/clip_selection.dart';
import '../clip_selection_providers.dart';
import '../my_cage_providers.dart';
import 'clip_selection_widgets.dart';
import 'clip_toast.dart';

/// 영상 선택 모드의 사용자 흐름 — 세 목록(카메라 탭·하이라이트·북마크) 공용.
///
/// 흐름(Figma 1497:14225): 작업이 끝나면 완료 토스트와 함께 선택 모드를 닫고,
/// 일부만 실패하면 **실패한 영상만 골라진 채** 남겨 다시 누를 수 있게 한다.
/// 취소하면 그때까지 끝난 것은 남고 선택 모드를 닫는다.
class ClipSelectionFlow {
  ClipSelectionFlow(this.ref, this.scope);
  final WidgetRef ref;
  final ClipSelectionScope scope;

  ClipSelectionController get _selection =>
      ref.read(clipSelectionProvider(scope).notifier);
  ClipBatchController get _batch => ref.read(clipBatchProvider(scope).notifier);
  List<String> get _ids => ref.read(clipSelectionProvider(scope)).ids;

  static void _error(BuildContext context, String text) =>
      showClipToast(context,
          text: text,
          icon: 'redesign_v2/priority_high',
          duration: const Duration(seconds: 3),
          bottom: kScreenToastBottom);

  static void showLimit(BuildContext context) => _error(context,
      'clip_select_limit'.tr(namedArgs: {'max': '${ClipSelection.maxCount}'}));

  /// 썸네일 탭(선택 모드) — 상한이면 안내.
  void toggle(BuildContext context, String id) {
    HapticFeedback.selectionClick();
    if (!_selection.toggle(id)) showLimit(context);
  }

  /// 꾹 누르기 — 모드 밖이면 그 영상을 고른 채 시작.
  void longPress(BuildContext context, String id) {
    HapticFeedback.mediumImpact();
    if (ref.read(clipSelectionProvider(scope)).active) {
      toggle(context, id);
    } else {
      _selection.enter(id);
    }
  }

  void toggleGroup(BuildContext context, List<String> group) {
    HapticFeedback.selectionClick();
    if (_selection.setGroup(group)) showLimit(context);
  }

  /// 작업 취소 안내 문구 키 — 디자이너 피드백(2026-10-21): 취소 전까지 한 것이
  /// 있으면 "영상 N/전체개 … 완료", 없으면 "작업을 취소했습니다". 공유는 다
  /// 받은 뒤에야 공유 창을 여니 취소하면 공유된 것이 없다.
  static String cancelledMessageKey(ClipBatchKind kind, int done) {
    if (done <= 0) return 'clip_select_job_cancelled';
    return switch (kind) {
      ClipBatchKind.save => 'clip_select_download_partial_done',
      ClipBatchKind.bookmarkAdd => 'clip_select_bookmark_partial_done',
      ClipBatchKind.bookmarkRemove => 'clip_select_unbookmark_partial_done',
      _ => 'clip_select_job_cancelled',
    };
  }

  static void _showCancelled(BuildContext context, ClipBatchKind kind,
          ClipBatchResult result, int total) =>
      showClipToast(context,
          text: cancelledMessageKey(kind, result.succeeded).tr(namedArgs: {
            'done': '${result.succeeded}',
            'total': '$total',
          }),
          bottom: kScreenToastBottom);

  void _settle(BuildContext context, ClipBatchResult result,
      {required String done,
      required String Function(int) partial,
      ClipBatchKind? kind,
      int total = 0}) {
    if (!context.mounted || result.ignored) return;
    if (result.cancelled) {
      // 멈춘 뒤 남은 것(실패 + 손대지 못한 것)만 골라진 채 둔다.
      _selection.keepOnly({...result.failed, ...result.remaining});
      _showCancelled(context, kind ?? ClipBatchKind.delete, result, total);
      return;
    }
    if (result.failed.isEmpty) {
      _selection.exit();
      showClipToast(context, text: done, bottom: kScreenToastBottom);
    } else {
      _selection.keepOnly(result.failed);
      _error(context, partial(result.failed.length));
    }
  }

  /// 0개에서 누른 동작 — 무반응이면 고장으로 읽힌다.
  bool _needsSelection(BuildContext context, List<String> ids) {
    // 작업 중 연타는 조용히 무시(진행 화면이 뜨기 전 같은 프레임의 두 번째 탭).
    if (_batch.busy) return true;
    if (ids.isNotEmpty) return false;
    _error(context, 'clip_select_none'.tr());
    return true;
  }

  Future<void> download(BuildContext context) async {
    final ids = _ids;
    if (_needsSelection(context, ids)) return;
    final result = await _batch.save(ids);
    if (!context.mounted || result.ignored) return;
    if (result.permissionDenied) {
      _error(context, 'clip_select_gallery_denied'.tr());
    } else if (result.cancelled) {
      _selection.exit();
      _showCancelled(context, ClipBatchKind.save, result, ids.length);
    } else {
      _settle(context, result,
          done: 'clip_download_done'.tr(),
          partial: (n) =>
              'clip_select_save_partial'.tr(namedArgs: {'count': '$n'}));
    }
  }

  Future<void> share(BuildContext context) async {
    final ids = _ids;
    if (_needsSelection(context, ids)) return;
    final result = await _batch.share(ids);
    if (!context.mounted || result.ignored) return;
    if (result.cancelled) {
      _showCancelled(context, ClipBatchKind.share, result, ids.length);
      return;
    }
    if (result.failed.isEmpty) {
      _selection.exit();
    } else {
      _selection.keepOnly(result.failed);
      _error(
          context,
          'clip_select_share_partial'
              .tr(namedArgs: {'count': '${result.failed.length}'}));
    }
  }

  Future<void> delete(BuildContext context) async {
    final ids = _ids;
    if (_needsSelection(context, ids)) return;
    final ok = await showVivaModal(context,
        message: 'clip_select_delete_confirm'.tr(),
        cancelLabel: 'clip_hide_cancel'.tr(),
        confirmLabel: 'clip_hide_action'.tr(),
        confirmKey: const Key('clip_select_delete_ok'));
    if (!ok || !context.mounted) return;
    final result = await _batch.delete(ids);
    if (!context.mounted) return;
    _settle(context, result,
        done: 'clip_select_deleted'.tr(),
        partial: (n) =>
            'clip_select_delete_partial'.tr(namedArgs: {'count': '$n'}));
  }

  /// 더보기 — 고른 것 중 북마크 안 된 게 있으면 "북마크 하기", 모두 북마크면
  /// "북마크 해제". "전체 선택"은 늘, "메모 삭제"는 북마크 목록에서만.
  Future<void> more(BuildContext context, Rect anchor,
      {required List<String> all}) async {
    if (_batch.busy) return;
    final ids = _ids;
    final favorites = ref.read(favoriteClipRepositoryProvider);
    final allBookmarked = ids.every(favorites.isFavorite);
    final items = <ClipSelectMenuItem<String>>[
      if (ids.isNotEmpty)
        allBookmarked
            ? ClipSelectMenuItem('unbookmark', 'clip_select_unbookmark'.tr())
            : ClipSelectMenuItem('bookmark', 'clip_select_bookmark'.tr()),
      ClipSelectMenuItem('all', 'clip_select_all'.tr()),
      if (ids.isNotEmpty && scope == ClipSelectionScope.bookmarks)
        ClipSelectMenuItem('memo', 'clip_memo_delete'.tr(), destructive: true),
    ];
    final choice =
        await showClipSelectMenu<String>(context, anchor: anchor, items: items);
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'all':
        if (_selection.selectAll(all)) showLimit(context);
      case 'bookmark' || 'unbookmark':
        final add = choice == 'bookmark';
        final result = await _batch.setBookmarked(ids, add);
        if (!context.mounted) return;
        _settle(context, result,
            done:
                (add ? 'clip_bookmark_saved_toast' : 'clip_select_unbookmarked')
                    .tr(),
            partial: (n) =>
                'clip_select_bookmark_partial'.tr(namedArgs: {'count': '$n'}),
            kind:
                add ? ClipBatchKind.bookmarkAdd : ClipBatchKind.bookmarkRemove,
            total: ids.length);
      case 'memo':
        final ok = await showVivaModal(context,
            message: 'clip_memo_delete_confirm'.tr(),
            cancelLabel: 'clip_memo_cancel'.tr(),
            confirmLabel: 'clip_memo_delete_action'.tr(),
            confirmKey: const Key('clip_select_memo_ok'));
        if (!ok || !context.mounted) return;
        final result = await _batch.deleteMemos(ids);
        if (!context.mounted) return;
        _settle(context, result,
            done: 'clip_select_memo_deleted'.tr(),
            partial: (n) =>
                'clip_select_memo_partial'.tr(namedArgs: {'count': '$n'}));
    }
  }

  /// 화면 이탈(뒤로) — 고른 영상이 있으면 묻는다(Figma 1497:14208).
  /// true면 선택을 버리고 나가도 된다.
  Future<bool> confirmLeave(BuildContext context) async {
    if (_ids.isEmpty) {
      _selection.exit();
      return true;
    }
    final ok = await showVivaModal(context,
        message: 'clip_select_leave_confirm'.tr(),
        cancelLabel: 'clip_select_leave_stay'.tr(),
        confirmLabel: 'clip_select_leave_ok'.tr(),
        confirmColor: context.glass.navSelected,
        confirmKey: const Key('clip_select_leave_ok'));
    if (ok) _selection.exit();
    return ok;
  }

  ClipSelectionActionBar actionBar(BuildContext context,
          {required List<String> Function() all}) =>
      ClipSelectionActionBar(
        onDownload: () => download(context),
        onShare: () => share(context),
        onDelete: () => delete(context),
        onMore: (anchor) => more(context, anchor, all: all()),
      );
}

/// 선택 모드 뒤로가기 — 고른 영상이 있으면 이탈 확인([onLeave]).
///
/// 안드로이드 시스템 뒤로는 [BackButtonListener]로 받는다 — 카메라 탭처럼 셸
/// 탭의 첫 화면이면 `PopScope`만으로는 GoRouter가 뒤로를 그 화면에 넘기지 않을
/// 수 있다. iOS 스와이프·`maybePop`은 `PopScope`가 막는다. 화면이 실제로 보일
/// 때만(TickerMode — 다른 탭이거나 위에 플레이어 등이 덮였으면 꺼진다)
/// 가로챈다. 일괄 작업 중엔 뒤로를 삼킨다.
class ClipSelectionBackGuard extends ConsumerWidget {
  const ClipSelectionBackGuard({
    super.key,
    required this.scope,
    required this.onLeave,
    required this.child,
  });

  final ClipSelectionScope scope;
  final Future<void> Function() onLeave;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(clipSelectionProvider(scope).select((s) => s.active));
    final busy = ref.watch(clipBatchProvider(scope)) != null;
    final visible = TickerMode.of(context);
    final guarding = active || busy;
    final popScope = PopScope(
      canPop: !guarding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) onLeave();
      },
      child: child,
    );
    // BackButtonListener는 Router 아래에서만 쓸 수 있다(앱은 늘 GoRouter).
    if (Router.maybeOf(context) == null) return popScope;
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!guarding || !visible) return false;
        if (!busy) await onLeave();
        return true;
      },
      child: popScope,
    );
  }
}
