/// 라이브 직접 녹화(2026-10-01 기획 `docs/superpowers/specs/2026-10-01-live-recording-design.md`).
///
/// 라이브 확대 화면(세로 목록 [녹화 시작]·가로 알약)에서 받고 있는 WebRTC
/// 영상을 최대 [kLiveRecordingLength] 동안 그대로 파일로 남긴다. 끊기면 거기까지 저장,
/// [kLiveRecordingMinLength] 미만이면 버린다. 기기에 먼저 보관하고, 뒤에서
/// R2로 올린다(2026-10-21 E단계 — `LiveRecordingUploadQueue`).
library;

/// 기능 스위치 — 실험 기능이라 별로면 이것 하나로 버튼·보관함 노출을 끈다.
const bool kLiveRecordingEnabled = true;

/// 한 번 녹화 최대 길이 — Figma "실시간 녹화"(1525:11231) "Max 2분 녹화 /
/// 2분 초과 시 자동 녹화 종료"(2026-10-21, 구 60초 고정 대체).
const Duration kLiveRecordingLength = Duration(minutes: 2);

/// 이보다 짧게 끊긴 녹화는 저장하지 않는다.
const Duration kLiveRecordingMinLength = Duration(seconds: 3);

/// 녹화를 시작할 수 있는지 — 영상이 실제로 나오는 중이어야 하고, 서버 시청
/// 제한(15분) 종료까지 최소 길이만큼은 남아 있어야 한다. 2분이 다 안 남아도
/// 시작하고 제한 시각에 거기까지 저장한다(2026-10-21 — 2분을 요구하면 시청
/// 13분 뒤엔 늘 막힌다). [liveUntil]이 없으면(구 서버) 제한 없음으로 본다.
bool canStartLiveRecording({
  required bool streaming,
  required DateTime? liveUntil,
  required DateTime now,
}) {
  if (!streaming) return false;
  if (liveUntil == null) return true;
  return liveUntil.difference(now) > kLiveRecordingMinLength;
}

/// 녹화가 끝난 이유.
enum LiveRecordingEnd {
  /// [kLiveRecordingLength]를 다 찍음.
  completed,

  /// 사용자가 [녹화 중단]·이탈 확인창 [중단하기].
  userStopped,

  /// 서버 시청 제한(15분) 시각 도달 — 정해진 끝이라 끊김과 달리 "저장 완료"로
  /// 안내한다(2026-10-21 계획 §9).
  limit,

  /// 연결 끊김·다른 기기 전환·재연결.
  interrupted,

  /// 화면 이탈·앱 백그라운드.
  left,
}

/// 끝난 녹화를 남길지.
bool shouldKeepLiveRecording(Duration recorded) =>
    recorded >= kLiveRecordingMinLength;

/// 서버가 받아 주는 녹화 길이 상한(`POST /recordings` `duration_ms`).
/// 2026-10-21 서버 60초 → 120초 배포(terra-server `feat/recording-max-120s`,
/// 요청 `docs/handoffs/2026-10-21-live-recording-max-120s-request.md`).
/// 넘는 녹화는 등록하지 않고 "업로드 대기"로 둔다(400을 받아 영구 실패로
/// 버리지 않게). 녹화 최대 길이([kLiveRecordingLength])와 같다.
const int kServerRecordingMaxMs = 120000;

/// 서버 파일 크기 상한(30MB). 단위가 MiB인지 확인 전이라 작은 쪽(10진 MB)으로
/// 거른다 — 넘으면 등록하지 않고 "업로드 실패"(로컬 보관은 유지).
const int kServerRecordingMaxBytes = 30 * 1000 * 1000;

/// 업로드 상태(Hive 녹화 행에 남는다).
enum LiveRecordingUploadState {
  /// 아직 안 올림(또는 일시 실패 뒤 재시도 대기 — [LiveRecording.nextAttemptAt]).
  pending,

  /// 올리는 중. 앱이 중간에 꺼지면 다음 실행 때 pending처럼 다시 한다.
  uploading,

  /// 서버 `ready` — 끝.
  ready,

  /// 다시 해도 안 되는 실패(400·403·404·30MB 초과·파일 없음). 자동 재시도 없음.
  failed,

  /// 서버 한도로 보류 — 길이 한도([kServerRecordingMaxMs]) 또는 계정 한도
  /// (409 `recording_quota_exceeded`). 사용자에겐 "업로드 대기".
  blocked,

  /// 사용자가 지웠는데 서버 DELETE가 아직 안 됨 — 목록에서 숨기고 다음
  /// 기회에 다시 지운다.
  deleting;

  static LiveRecordingUploadState parse(Object? raw) =>
      values.where((v) => v.name == raw).firstOrNull ?? pending;
}

/// [LiveRecording.uploadError] 값.
abstract final class LiveRecordingUploadError {
  /// blocked — 서버 길이 한도 초과(앱 상수로 미리 거름).
  static const lengthLimit = 'length_limit';

  /// blocked — 409 `recording_quota_exceeded`.
  static const quota = 'quota';

  /// failed — 30MB 초과.
  static const tooLarge = 'too_large';

  /// failed — 녹화 파일이 없다.
  static const fileMissing = 'file_missing';
}

/// 보관함 카드의 업로드 표시.
enum LiveRecordingUploadBadge { none, uploading, waiting, failed }

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
    this.width,
    this.height,
    this.recordingId,
    this.uploadState = LiveRecordingUploadState.pending,
    this.uploadError,
    this.uploadAttempts = 0,
    this.nextAttemptAt,
  });

  final String id;
  final String ownerId;
  final String cameraId;
  final DateTime startedAt;
  /// 파일 실제 길이(mp4 `mvhd`) — 못 읽었으면 녹화 타이머 값. 서버 등록
  /// `duration_ms`도 이 값이다(타이머는 파일보다 몇 초 길다).
  final int durationMs;
  /// 앱 문서 디렉토리 기준 **상대** 경로 — iOS는 앱 업데이트마다 컨테이너
  /// 절대 경로가 바뀌어 절대 경로를 저장하면 파일을 잃는다.
  final String filePath;
  final String? thumbPath;

  /// R2 업로드 완료 시각. null = 기기에만 있음.
  final DateTime? uploadedAt;

  /// 영상 크기(mp4 `tkhd`). 모르면 null.
  final int? width;
  final int? height;

  /// 서버 `live_recordings.id`. 등록 전 null. 서버가 23시간 30분 넘은
  /// 등록을 새로 만들면 바뀐다.
  final String? recordingId;
  final LiveRecordingUploadState uploadState;

  /// 마지막 오류 코드([LiveRecordingUploadError] 또는 `http_<코드>`·`network`).
  final String? uploadError;

  /// 연속 일시 실패 횟수(백오프 계산용, 성공하면 0).
  final int uploadAttempts;

  /// 이 시각 전엔 다시 시도하지 않는다(일시 실패 백오프). null = 바로.
  final DateTime? nextAttemptAt;

  Duration get duration => Duration(milliseconds: durationMs);

  /// 보관함 카드 표시.
  LiveRecordingUploadBadge get uploadBadge => switch (uploadState) {
        LiveRecordingUploadState.uploading => LiveRecordingUploadBadge.uploading,
        LiveRecordingUploadState.pending ||
        LiveRecordingUploadState.blocked =>
          LiveRecordingUploadBadge.waiting,
        LiveRecordingUploadState.failed => LiveRecordingUploadBadge.failed,
        LiveRecordingUploadState.ready ||
        LiveRecordingUploadState.deleting =>
          LiveRecordingUploadBadge.none,
      };

  static const _keep = Object();

  LiveRecording copyWith({
    int? durationMs,
    Object? thumbPath = _keep,
    Object? uploadedAt = _keep,
    Object? recordingId = _keep,
    LiveRecordingUploadState? uploadState,
    Object? uploadError = _keep,
    int? uploadAttempts,
    Object? nextAttemptAt = _keep,
  }) =>
      LiveRecording(
        id: id,
        ownerId: ownerId,
        cameraId: cameraId,
        startedAt: startedAt,
        durationMs: durationMs ?? this.durationMs,
        filePath: filePath,
        thumbPath:
            identical(thumbPath, _keep) ? this.thumbPath : thumbPath as String?,
        uploadedAt: identical(uploadedAt, _keep)
            ? this.uploadedAt
            : uploadedAt as DateTime?,
        width: width,
        height: height,
        recordingId: identical(recordingId, _keep)
            ? this.recordingId
            : recordingId as String?,
        uploadState: uploadState ?? this.uploadState,
        uploadError: identical(uploadError, _keep)
            ? this.uploadError
            : uploadError as String?,
        uploadAttempts: uploadAttempts ?? this.uploadAttempts,
        nextAttemptAt: identical(nextAttemptAt, _keep)
            ? this.nextAttemptAt
            : nextAttemptAt as DateTime?,
      );

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
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (recordingId != null) 'recording_id': recordingId,
        'upload_state': uploadState.name,
        if (uploadError != null) 'upload_error': uploadError,
        if (uploadAttempts != 0) 'upload_attempts': uploadAttempts,
        if (nextAttemptAt != null)
          'next_attempt_at': nextAttemptAt!.toUtc().toIso8601String(),
      };

  static LiveRecording? tryFromJson(Map<String, dynamic> j) {
    try {
      final uploaded = j['uploaded_at'] as String?;
      final next = j['next_attempt_at'] as String?;
      return LiveRecording(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String,
        cameraId: j['camera_id'] as String,
        startedAt: DateTime.parse(j['started_at'] as String),
        durationMs: (j['duration_ms'] as num).toInt(),
        filePath: j['file_path'] as String,
        thumbPath: j['thumb_path'] as String?,
        uploadedAt: uploaded == null ? null : DateTime.parse(uploaded),
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        recordingId: j['recording_id'] as String?,
        // 업로드 필드가 없는 옛 행(0.156.0+421 이전)은 pending으로 읽는다.
        uploadState: LiveRecordingUploadState.parse(j['upload_state']),
        uploadError: j['upload_error'] as String?,
        uploadAttempts: (j['upload_attempts'] as num?)?.toInt() ?? 0,
        nextAttemptAt: next == null ? null : DateTime.parse(next),
      );
    } catch (_) {
      return null;
    }
  }
}
