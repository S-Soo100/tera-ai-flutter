/// 카메라 표시용 연결 상태. `cameras.is_online`(서버 판정)에 `last_seen_at`
/// 시효를 결합한다 — is_online만 믿으면 서버의 오프라인 판정 지연이나 앱측
/// Realtime 이벤트 소실 시 stale 표시가 남는다.
enum CameraPresence { online, stale, offline }

/// [staleAfter]: last_seen이 이보다 오래되면 online이어도 stale(응답 지연)로
/// 강등. 하트비트가 1~3분 간격이므로 5분 = 약 2회 연속 누락 수준.
CameraPresence cameraPresence({
  required bool isOnline,
  required DateTime? lastSeenAt,
  required DateTime now,
  Duration staleAfter = const Duration(minutes: 5),
}) {
  if (!isOnline) return CameraPresence.offline;
  if (lastSeenAt == null) return CameraPresence.online;
  final age = now.toUtc().difference(lastSeenAt.toUtc());
  return age > staleAfter ? CameraPresence.stale : CameraPresence.online;
}
