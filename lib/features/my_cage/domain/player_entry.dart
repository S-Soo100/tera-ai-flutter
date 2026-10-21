/// 세로 재생목록 플레이어의 항목 한 개 — 움직임 영상(motion_clips) 또는
/// 직접 녹화(폰 파일, `LiveRecording`).
///
/// 보관함(북마크 화면)은 두 종류를 시각순으로 섞어 보여 주고, 플레이어도
/// 같은 순서로 넘긴다(2026-10-21 사용자 결정). 재생목록·라우트 extra·메모
/// 저장 키가 모두 문자열이라 항목은 [key] 문자열로 오간다: 움직임 영상은
/// clip id 그대로, 직접 녹화는 `rec:<녹화 id>`. clip id는 UUID라 접두와
/// 겹치지 않는다. 문자열을 직접 자르지 말고 [PlayerEntry.parse]를 거칠 것.
sealed class PlayerEntry {
  const PlayerEntry();

  /// 재생목록·메모 저장에 쓰는 문자열 키.
  String get key;

  static PlayerEntry parse(String key) =>
      key.startsWith(RecordingEntry.prefix) &&
              key.length > RecordingEntry.prefix.length
          ? RecordingEntry(key.substring(RecordingEntry.prefix.length))
          : ClipEntry(key);
}

/// 움직임 영상 — [key]는 clip id.
final class ClipEntry extends PlayerEntry {
  const ClipEntry(this.clipId);
  final String clipId;

  @override
  String get key => clipId;
}

/// 직접 녹화 — [key]는 `rec:<녹화 id>`. 메모도 이 키로 저장해 clip id와
/// 겹치지 않게 한다(`HiveClipMemoRepository`).
final class RecordingEntry extends PlayerEntry {
  const RecordingEntry(this.recordingId);
  static const prefix = 'rec:';
  final String recordingId;

  @override
  String get key => '$prefix$recordingId';
}
