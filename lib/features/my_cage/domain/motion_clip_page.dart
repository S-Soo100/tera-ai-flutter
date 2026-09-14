import 'motion_clip.dart';

typedef MotionClipCursor = ({DateTime startedAt, String id});
typedef MotionClipPage = ({
  List<MotionClip> items,
  MotionClipCursor? nextCursor,
  bool hasMore
});
typedef ClipDateRange = ({DateTime start, DateTime endExclusive});
typedef ClipFeedQuery = ({
  String ownerId,
  String cameraId,
  ClipDateRange? range
});
