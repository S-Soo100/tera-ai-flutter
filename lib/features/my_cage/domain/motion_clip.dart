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
  final String? action; // 행동 분류. null = 미분류. (motion_clips엔 아직 없음)

  const MotionClip({
    required this.id,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    this.motionScore,
    this.thumbnailKey,
    this.action,
  });

  MotionClip copyWith({String? action}) => MotionClip(
        id: id,
        cameraId: cameraId,
        startedAt: startedAt,
        durationSec: durationSec,
        motionScore: motionScore,
        thumbnailKey: thumbnailKey,
        action: action ?? this.action,
      );

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
      // 후속 연결점: 분류 저장소 생기면 여기만 교체.
      // 예) motion_clip_labels 조인 시: (j['motion_clip_labels'] as List?)?.isNotEmpty == true
      //        ? (j['motion_clip_labels'] as List).first['action'] as String? : null
      action: j['action'] as String?,
    );
  }
}
