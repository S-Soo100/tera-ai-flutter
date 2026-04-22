class Clip {
  final String id;
  final String userId;
  final String? petId;
  final String cameraId;
  final DateTime startedAt;
  final double durationSec;
  final bool hasMotion;
  final int? motionFrames;
  final String filePath;
  final int? fileSize;
  final String? codec;
  final int? width;
  final int? height;
  final double? fps;
  final String? thumbnailPath;
  final DateTime createdAt;

  const Clip({
    required this.id,
    required this.userId,
    this.petId,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    required this.hasMotion,
    this.motionFrames,
    required this.filePath,
    this.fileSize,
    this.codec,
    this.width,
    this.height,
    this.fps,
    this.thumbnailPath,
    required this.createdAt,
  });

  factory Clip.fromJson(Map<String, dynamic> json) {
    return Clip(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      petId: json['pet_id'] as String?,
      cameraId: json['camera_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      durationSec: (json['duration_sec'] as num).toDouble(),
      hasMotion: json['has_motion'] as bool,
      motionFrames: json['motion_frames'] as int?,
      filePath: json['file_path'] as String,
      fileSize: json['file_size'] as int?,
      codec: json['codec'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      fps: json['fps'] != null ? (json['fps'] as num).toDouble() : null,
      thumbnailPath: json['thumbnail_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
