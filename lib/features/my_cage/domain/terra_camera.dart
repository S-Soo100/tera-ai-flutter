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

  /// 펌웨어 버전(서버 보고값). 라이브 기록에 시점값으로 붙인다(2026-09-25).
  final String? firmwareVer;
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
    this.firmwareVer,
    required this.isOnline,
    this.lastSeenAt,
    this.enclosureId,
    required this.createdAt,
    this.rotate180 = false,
    this.rotate180Capable = false,
  });

  /// 생존 신호 시각([lastSeenAt])만 빼고 같은가. 화면이 쓰는 값은 전부 비교한다
  /// — 필드를 추가하면 여기에도 넣을 것(빠뜨리면 그 값의 변경이 화면에 안 온다).
  bool sameIgnoringHeartbeat(TerraCamera other) =>
      id == other.id &&
      cameraId == other.cameraId &&
      name == other.name &&
      model == other.model &&
      resolution == other.resolution &&
      firmwareVer == other.firmwareVer &&
      isOnline == other.isOnline &&
      enclosureId == other.enclosureId &&
      createdAt == other.createdAt &&
      rotate180 == other.rotate180 &&
      rotate180Capable == other.rotate180Capable;

  factory TerraCamera.fromJson(Map<String, dynamic> j) {
    final capabilities = j['capabilities'];
    return TerraCamera(
      id: j['id'] as String? ?? '',
      cameraId: j['camera_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      model: j['model'] as String?,
      resolution: j['resolution'] as String?,
      firmwareVer: j['firmware_ver'] as String?,
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

/// 생존 신호 시각만 다른 두 목록은 같은 목록으로 본다(개수·순서 포함 비교).
///
/// 온라인 카메라는 15초마다 `last_seen_at`을 갱신하고 그때마다 Realtime 이벤트가
/// 온다. 이걸 "목록 변경"으로 흘리면 세트·리포트 등 하위 provider가 전부 다시
/// 돌아 홈이 15초마다 깜빡였다(2026-09-19 실기기). 앱은 그 시각을 쓰지 않는다.
bool sameCamerasIgnoringHeartbeat(List<TerraCamera> a, List<TerraCamera> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].sameIgnoringHeartbeat(b[i])) return false;
  }
  return true;
}
