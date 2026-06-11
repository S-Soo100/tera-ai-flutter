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
