import 'motion_clip.dart';

/// [token]은 petcam-api `/highlights`의 불투명 서버 커서(정책 v2 전체 영상
/// 목록). Supabase 직결 페이징(`MotionClipRepository.listPage`)은 null.
typedef MotionClipCursor = ({DateTime startedAt, String id, String? token});
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
