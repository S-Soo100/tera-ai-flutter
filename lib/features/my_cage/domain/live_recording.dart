/// 라이브 직접 녹화(2026-10-01 기획 `docs/superpowers/specs/2026-10-01-live-recording-design.md`).
///
/// 가로 전체화면 라이브에서 버튼을 누르면 받고 있는 WebRTC 영상을
/// [kLiveRecordingLength] 동안 그대로 파일로 남긴다. 끊기면 거기까지 저장,
/// [kLiveRecordingMinLength] 미만이면 버린다. 1단계는 기기 안 보관만 —
/// R2 업로드는 서버 계약 확정 뒤(`uploadedAt`이 그때 채워진다).
library;

/// 기능 스위치 — 실험 기능이라 별로면 이것 하나로 버튼·보관함 노출을 끈다.
const bool kLiveRecordingEnabled = true;

/// 한 번 녹화 길이(사용자 결정 — 누른 순간부터 60초).
const Duration kLiveRecordingLength = Duration(seconds: 60);

/// 이보다 짧게 끊긴 녹화는 저장하지 않는다.
const Duration kLiveRecordingMinLength = Duration(seconds: 3);

/// 녹화를 시작할 수 있는지 — 영상이 실제로 나오는 중이어야 하고, 서버 시청
/// 제한(15분) 종료까지 녹화 길이만큼 남아 있어야 한다(중간에 잘리는 걸 미리
/// 막는다). [liveUntil]이 없으면(구 서버) 제한 없음으로 본다.
bool canStartLiveRecording({
  required bool streaming,
  required DateTime? liveUntil,
  required DateTime now,
}) {
  if (!streaming) return false;
  if (liveUntil == null) return true;
  return liveUntil.difference(now) >= kLiveRecordingLength;
}

/// 녹화가 끝난 이유.
enum LiveRecordingEnd {
  /// 60초 다 찍음.
  completed,

  /// 사용자가 정지 버튼.
  userStopped,

  /// 연결 끊김·시청 제한·다른 기기 전환·재연결.
  interrupted,

  /// 화면 이탈·앱 백그라운드.
  left,
}

/// 끝난 녹화를 남길지.
bool shouldKeepLiveRecording(Duration recorded) =>
    recorded >= kLiveRecordingMinLength;

/// 보관된 녹화 한 건(기기 안 mp4 + 첫 장면 썸네일).
class LiveRecording {
  const LiveRecording({
    required this.id,
    required this.ownerId,
    required this.cameraId,
    required this.startedAt,
    required this.durationMs,
    required this.filePath,
    this.thumbPath,
    this.uploadedAt,
  });

  final String id;
  final String ownerId;
  final String cameraId;
  final DateTime startedAt;
  final int durationMs;
  /// 앱 문서 디렉토리 기준 **상대** 경로 — iOS는 앱 업데이트마다 컨테이너
  /// 절대 경로가 바뀌어 절대 경로를 저장하면 파일을 잃는다.
  final String filePath;
  final String? thumbPath;

  /// R2 업로드 완료 시각(2단계). null = 기기에만 있음.
  final DateTime? uploadedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'camera_id': cameraId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'duration_ms': durationMs,
        'file_path': filePath,
        if (thumbPath != null) 'thumb_path': thumbPath,
        if (uploadedAt != null)
          'uploaded_at': uploadedAt!.toUtc().toIso8601String(),
      };

  static LiveRecording? tryFromJson(Map<String, dynamic> j) {
    try {
      final uploaded = j['uploaded_at'] as String?;
      return LiveRecording(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String,
        cameraId: j['camera_id'] as String,
        startedAt: DateTime.parse(j['started_at'] as String),
        durationMs: (j['duration_ms'] as num).toInt(),
        filePath: j['file_path'] as String,
        thumbPath: j['thumb_path'] as String?,
        uploadedAt: uploaded == null ? null : DateTime.parse(uploaded),
      );
    } catch (_) {
      return null;
    }
  }
}
