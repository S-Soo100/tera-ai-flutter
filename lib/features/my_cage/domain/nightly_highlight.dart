/// terra-api GET /clips/highlights 항목(보기 전용). clip_id=motion_clips.id(미러)라
/// 썸네일(motionThumbnailProvider)·재생(MotionClipPlayerScreen) 재사용.
class NightlyHighlight {
  final String clipId;
  final DateTime startedAt;
  final String vlmAction;
  final double confidence;
  final String careLevel; // 'care' | 'enrichment'

  const NightlyHighlight({
    required this.clipId,
    required this.startedAt,
    required this.vlmAction,
    required this.confidence,
    required this.careLevel,
  });

  factory NightlyHighlight.fromJson(Map<String, dynamic> j) {
    return NightlyHighlight(
      clipId: j['clip_id'] as String? ?? '',
      startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '') ??
          DateTime.now(),
      vlmAction: j['vlm_action'] as String? ?? 'unseen',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      careLevel: j['care_level'] as String? ?? 'care',
    );
  }
}
