/// 세로 재생목록 플레이어의 항목 한 개 — 움직임 영상(motion_clips) 또는
/// 직접 녹화(폰 파일 [RecordingEntry] / 서버에만 있는 녹화 [ServerRecordingEntry]).
///
/// 보관함(북마크 화면)·카메라 탭 시간대별 목록은 두 종류를 시각순으로 섞어
/// 보여 주고, 플레이어도 같은 순서로 넘긴다(2026-10-21 사용자 결정). 재생목록·
/// 라우트 extra·메모 저장 키·영상 선택 id가 모두 문자열이라 항목은 [key]
/// 문자열로 오간다:
/// - 움직임 영상: clip id 그대로
/// - 이 폰의 녹화: `rec:<로컬 녹화 id>`
/// - 서버에만 있는 녹화(다른 폰·재설치 후): `rec:srv:<서버 live_recordings.id>`
///
/// clip id·로컬 녹화 id는 UUID라 접두와 겹치지 않는다. 문자열을 직접 자르지
/// 말고 [PlayerEntry.parse]를 거칠 것.
sealed class PlayerEntry {
  const PlayerEntry();

  /// 재생목록·메모 저장·영상 선택에 쓰는 문자열 키.
  String get key;

  /// 직접 녹화(폰·서버)인지 — 북마크 하기/해제·숨기기 대상이 아니다.
  bool get isRecording => this is! ClipEntry;

  static PlayerEntry parse(String key) {
    if (key.startsWith(ServerRecordingEntry.prefix) &&
        key.length > ServerRecordingEntry.prefix.length) {
      return ServerRecordingEntry(
          key.substring(ServerRecordingEntry.prefix.length));
    }
    if (key.startsWith(RecordingEntry.prefix) &&
        key.length > RecordingEntry.prefix.length) {
      return RecordingEntry(key.substring(RecordingEntry.prefix.length));
    }
    return ClipEntry(key);
  }
}

/// 움직임 영상 — [key]는 clip id.
final class ClipEntry extends PlayerEntry {
  const ClipEntry(this.clipId);
  final String clipId;

  @override
  String get key => clipId;
}

/// 이 폰의 직접 녹화 — [key]는 `rec:<로컬 녹화 id>`. 메모도 이 키로 저장해
/// clip id와 겹치지 않게 한다(`HiveClipMemoRepository`).
final class RecordingEntry extends PlayerEntry {
  const RecordingEntry(this.recordingId);
  static const prefix = 'rec:';
  final String recordingId;

  @override
  String get key => '$prefix$recordingId';
}

/// 서버에만 있는 직접 녹화 — [key]는 `rec:srv:<서버 id>`. 재생·썸네일은
/// 서버 presigned URL(`GET /recordings/{id}/url`·`/thumbnail/url`).
///
/// 같은 녹화가 이 폰에도 있으면(로컬 행의 `recordingId` == 서버 id) 목록은
/// 로컬 쪽([RecordingEntry])만 남긴다 — 그래서 한 폰 안에서 같은 녹화는 늘
/// 같은 키(같은 메모)로 열린다. 메모는 폰에만 저장돼 다른 폰으로 넘어가지
/// 않으므로 키 이전(마이그레이션)은 하지 않는다.
final class ServerRecordingEntry extends PlayerEntry {
  const ServerRecordingEntry(this.serverId);
  static const prefix = 'rec:srv:';
  final String serverId;

  @override
  String get key => '$prefix$serverId';
}
