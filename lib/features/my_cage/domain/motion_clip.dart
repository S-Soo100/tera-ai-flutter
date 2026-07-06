/// Supabase `motion_clips` 테이블 매핑 (terra-server P4 카메라 모션 클립).
///
/// 컬럼: id, camera_id, enclosure_id, owner_id, started_at, duration_sec,
///       r2_key, thumbnail_key, motion_score, width, height, fps, created_at.
/// 재생 URL은 terra-api GET /clips/{id}/url 로 별도 발급(여기 담지 않음).
class MotionClip {
  final String id;
  final String cameraId;
  final DateTime startedAt;
  final double durationSec;
  final double? motionScore;
  final String? thumbnailKey;

  const MotionClip({
    required this.id,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    this.motionScore,
    this.thumbnailKey,
  });

  factory MotionClip.fromJson(Map<String, dynamic> j) {
    return MotionClip(
      id: j['id'] as String? ?? '',
      cameraId: j['camera_id'] as String? ?? '',
      startedAt: j['started_at'] != null
          ? DateTime.tryParse(j['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationSec: (j['duration_sec'] as num?)?.toDouble() ?? 0,
      motionScore: (j['motion_score'] as num?)?.toDouble(),
      thumbnailKey: j['thumbnail_key'] as String?,
    );
  }
}
