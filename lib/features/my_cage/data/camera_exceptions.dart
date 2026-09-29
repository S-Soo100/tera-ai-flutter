/// 카메라 등록 시 (user_id, host, port, path) 유니크 위반 — HTTP 409
class CameraConflictException implements Exception {
  final String detail;
  const CameraConflictException(this.detail);

  @override
  String toString() => 'CameraConflictException: $detail';
}

/// POST /cameras/test-connection 400 응답 — RTSP 연결 실패
class CameraTestFailedException implements Exception {
  final String detail;
  const CameraTestFailedException(this.detail);

  @override
  String toString() => 'CameraTestFailedException: $detail';
}

/// Backend 4xx/5xx 기타 응답
class BackendException implements Exception {
  final int statusCode;
  final String detail;
  const BackendException(this.statusCode, this.detail);

  @override
  String toString() => 'BackendException($statusCode): $detail';
}

/// GET /clips/{id}/file 410 — 파일이 DB에는 있으나 디스크에서 사라짐
class ClipMissingException implements Exception {
  final String clipId;
  const ClipMissingException(this.clipId);

  @override
  String toString() => 'ClipMissingException: clip $clipId not found on disk';
}

/// WebRTC offer 504 — 카메라가 시그널링 타임아웃 내 응답 없음
class CameraUnresponsiveException implements Exception {
  const CameraUnresponsiveException();

  @override
  String toString() => 'CameraUnresponsiveException: no response from camera';
}

/// WebRTC offer 502 — 시그널링 게이트웨이 오류
class SignalingGatewayException implements Exception {
  const SignalingGatewayException();

  @override
  String toString() => 'SignalingGatewayException: signaling gateway error';
}

// ── 라이브 시청 제한 (2026-09-30, terra-server APP_LIVE_VIEW_LIMIT) ─────────────
// 셋 다 **자동 재시도 금지** — 사용자가 버튼을 눌렀을 때만 다시 요청한다.

/// WebRTC offer 409 `live_in_use` — 같은 카메라를 다른 기기가 보고 있다.
/// [viewer]는 서버가 준 그 기기 이름("iPhone 15"). `takeover: true`로 다시
/// 보내면 가져온다.
class LiveInUseException implements Exception {
  final String? viewer;
  const LiveInUseException(this.viewer);

  @override
  String toString() => 'LiveInUseException: $viewer';
}

/// WebRTC offer 429 `live_cooldown` — 15분 시청 뒤 5분 쉼. [retryAfter] 뒤 가능.
class LiveCooldownException implements Exception {
  final Duration retryAfter;
  const LiveCooldownException(this.retryAfter);

  @override
  String toString() => 'LiveCooldownException: ${retryAfter.inSeconds}s';
}

/// WebRTC offer 429 `rate_limited` — 카메라당 시간당 offer 상한(재연결 루프
/// 안전망). 구 서버는 code 없이 문자열 detail만 준다 — 그것도 이쪽이다.
class LiveRateLimitedException implements Exception {
  final Duration retryAfter;
  const LiveRateLimitedException(this.retryAfter);

  @override
  String toString() => 'LiveRateLimitedException: ${retryAfter.inSeconds}s';
}
