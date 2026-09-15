import 'motion_clip_page.dart';

/// A visibility snapshot never changes the source clip or its activity records.
class ClipVisibilityState {
  const ClipVisibilityState(
      {this.hiddenIds = const {},
      this.loading = true,
      this.hidingIds = const {},
      this.loadError,
      this.saveError,
      this.failedClipId});
  final Set<String> hiddenIds;
  final bool loading;
  final Set<String> hidingIds;
  final Object? loadError, saveError;
  final String? failedClipId;
}

typedef VisibleClipPageLoader = Future<MotionClipPage> Function(
    MotionClipCursor? before);

/// Advance the raw compound cursor through completely hidden pages. A malformed
/// cursor is an error, never an empty successful end or an infinite retry loop.
Future<MotionClipPage> loadVisibleClipPage({
  required VisibleClipPageLoader load,
  required Set<String> Function() hiddenIds,
  MotionClipCursor? before,
}) async {
  var cursor = before;
  final visited = <MotionClipCursor>{if (before != null) before};
  while (true) {
    final page = await load(cursor);
    final next = page.nextCursor;
    if (page.hasMore && (next == null || !visited.add(next))) {
      throw StateError('Clip pagination cursor did not advance');
    }
    final hidden = hiddenIds();
    final visible = page.items
        .where((clip) => !hidden.contains(clip.id))
        .toList(growable: false);
    if (visible.isNotEmpty || !page.hasMore) {
      return (items: visible, nextCursor: next, hasMore: page.hasMore);
    }
    cursor = next;
  }
}
