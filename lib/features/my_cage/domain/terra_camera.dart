/// Supabase `cameras` 테이블 매핑 (terra-server 스키마 기준).
///
/// 컬럼: id, owner_id, enclosure_id, camera_id(text), name, model,
///       firmware_ver, resolution, fps, clip_sec, stream_mode, stream_until,
///       is_online(bool), last_seen_at, created_at, updated_at,
///       rotate_180(bool), capabilities(JSONB) — 회신 2026-09-08 §4·§5
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

  /// 현재 설정값(선언적) — 쓰기는 반드시 REST `PATCH /cameras/{id}` 경유
  /// (서버가 MQTT 명령 발행 + 재연결 동기화. DB 직결 UPDATE는 명령이 안 나간다).
  final bool rotate180;

  /// `capabilities.rotate_180 == true` — 펌웨어가 MQTT 연결 시마다 보고.
  /// null/키 없음 = 구 펌웨어 → 토글 숨김(회신 §4, LED dimmable과 같은 문법).
  final bool rotate180Capable;

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
    this.rotate180 = false,
    this.rotate180Capable = false,
  });

  factory TerraCamera.fromJson(Map<String, dynamic> j) {
    final capabilities = j['capabilities'];
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
      rotate180: j['rotate_180'] as bool? ?? false,
      rotate180Capable:
          capabilities is Map && capabilities['rotate_180'] == true,
    );
  }
}
