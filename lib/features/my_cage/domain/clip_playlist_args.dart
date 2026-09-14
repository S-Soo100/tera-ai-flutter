import 'motion_clip_page.dart';

enum ClipPlaybackSource { feed, highlight, bookmark, single }

class ClipPlaylistArgs {
  const ClipPlaylistArgs(
      {required this.playlist,
      this.playFromSec = const {},
      this.source = ClipPlaybackSource.single,
      this.cameraId,
      this.rangeStart,
      this.rangeEndExclusive,
      this.nextCursor,
      this.hasMore = false,
      this.highlightBatchId});
  final List<String> playlist;
  final Map<String, double> playFromSec;
  final ClipPlaybackSource source;
  final String? cameraId;

  /// 카메라 홈에서 보고 있던 기간. 둘 다 null이면 전체 기간이다.
  final DateTime? rangeStart, rangeEndExclusive;
  final MotionClipCursor? nextCursor;
  final bool hasMore;
  final String? highlightBatchId;
}
