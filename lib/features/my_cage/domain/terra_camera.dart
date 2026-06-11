/// Supabase `cameras` 테이블 매핑 (terra-server 스키마 기준).
///
/// 컬럼: id, owner_id, enclosure_id, camera_id(text), name, model,
///       firmware_ver, resolution, fps, clip_sec, stream_mode, stream_until,
///       is_online(bool), last_seen_at, created_at, updated_at
class TerraCamera {
  final String id;
  final String cameraId; // camera_id: 예 "p4cam-79b5d844"
  final String name;
  final String? model;
  final String? resolution;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? enclosureId;
  final DateTime createdAt;

  const TerraCamera({
    required this.id,
    required this.cameraId,
    required this.name,
    this.model,
    this.resolution,
    required this.isOnline,
    this.lastSeenAt,
    this.enclosureId,
    required this.createdAt,
  });

  factory TerraCamera.fromJson(Map<String, dynamic> j) {
    return TerraCamera(
      id: j['id'] as String? ?? '',
      cameraId: j['camera_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      model: j['model'] as String?,
      resolution: j['resolution'] as String?,
      isOnline: j['is_online'] as bool? ?? false,
      lastSeenAt: j['last_seen_at'] != null
          ? DateTime.tryParse(j['last_seen_at'].toString())
          : null,
      enclosureId: j['enclosure_id'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
