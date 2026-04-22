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
