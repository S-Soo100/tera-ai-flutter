/// 확인 상태. pending=미확인, confirmed=AI행동 맞음, corrected=사용자가 다른 행동으로 정정.
enum HighlightReview { pending, confirmed, corrected }

/// terra-api GET /clips/highlights 항목. clip_id=motion_clips.id(미러 동일 UUID)라
/// 썸네일(motionThumbnailProvider)·재생(MotionClipPlayerScreen) 재사용 가능.
class NightlyHighlight {
  final String clipId;
  final DateTime startedAt;
  final String vlmAction; // 'drinking' | 'hand_feeding' | ...
  final double confidence; // 0~1
  final String careLevel; // 'care' | 'enrichment'
  final HighlightReview review;
  final String? correctedAction; // review==corrected일 때 정정된 action

  const NightlyHighlight({
    required this.clipId,
    required this.startedAt,
    required this.vlmAction,
    required this.confidence,
    required this.careLevel,
    required this.review,
    this.correctedAction,
  });

  NightlyHighlight copyWith(
      {HighlightReview? review, String? correctedAction}) {
    return NightlyHighlight(
      clipId: clipId,
      startedAt: startedAt,
      vlmAction: vlmAction,
      confidence: confidence,
      careLevel: careLevel,
      review: review ?? this.review,
      correctedAction: correctedAction ?? this.correctedAction,
    );
  }

  factory NightlyHighlight.fromJson(Map<String, dynamic> j) {
    final uc = j['user_confirmed'];
    HighlightReview review;
    String? corrected;
    if (uc == true) {
      review = HighlightReview.confirmed;
    } else if (uc is String && uc.isNotEmpty) {
      review = HighlightReview.corrected;
      corrected = uc;
    } else {
      review = HighlightReview.pending; // null / false
    }
    return NightlyHighlight(
      clipId: j['clip_id'] as String? ?? '',
      startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '') ??
          DateTime.now(),
      vlmAction: j['vlm_action'] as String? ?? 'unseen',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      careLevel: j['care_level'] as String? ?? 'care',
      review: review,
      correctedAction: corrected,
    );
  }
}
