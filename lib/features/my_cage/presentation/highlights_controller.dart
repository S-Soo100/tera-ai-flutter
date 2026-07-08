import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/highlight_repository.dart';
import '../domain/nightly_highlight.dart';

/// "어젯밤" 시작 = 어제 18:00(로컬). now 기준.
DateTime lastNightSince(DateTime now) {
  final today18 = DateTime(now.year, now.month, now.day, 18);
  return today18.subtract(const Duration(days: 1));
}

/// 어젯밤 하이라이트 로드 + 확인/정정/오탐 로컬 반영. 홈 배지·리포트 화면 공용.
class HighlightsController
    extends StateNotifier<AsyncValue<List<NightlyHighlight>>> {
  HighlightsController(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final HighlightRepository _repo;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.list(since: lastNightSince(DateTime.now()));
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// 👍 확정 = vlm_action 그대로 GT 제출 + 로컬 confirmed.
  Future<void> confirm(NightlyHighlight h) async {
    await _repo.submitLabel(h.clipId, h.vlmAction);
    _patch(h.clipId,
        (x) => x.copyWith(review: HighlightReview.confirmed));
  }

  /// 정정 = 선택 action GT 제출 + 로컬 corrected.
  Future<void> correct(NightlyHighlight h, String action) async {
    await _repo.submitLabel(h.clipId, action);
    _patch(
        h.clipId,
        (x) => x.copyWith(
            review: HighlightReview.corrected, correctedAction: action));
  }

  /// 오탐 = 서버 저장 없이 목록에서 제거(세션-로컬).
  void dismiss(String clipId) {
    final cur = state.valueOrNull ?? const [];
    state = AsyncValue.data(
        cur.where((h) => h.clipId != clipId).toList());
  }

  void _patch(
      String clipId, NightlyHighlight Function(NightlyHighlight) f) {
    final cur = state.valueOrNull ?? const [];
    state = AsyncValue.data([
      for (final h in cur) h.clipId == clipId ? f(h) : h,
    ]);
  }
}
