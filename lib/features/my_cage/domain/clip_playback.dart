/// 클립 재생 시작점 판정 — ClipPlaylistPlayerScreen·MotionClipPlayerScreen 공용.
///
/// 서버가 준 재생 시작점(`play_from_sec`,
/// [NightlyHighlight.playFromSec][../domain/nightly_highlight.dart])을 실제
/// seek 대상으로 확정한다. seek은 플레이어 초기화 완료(duration 확보) 뒤
/// **첫 재생 전에 클립당 1회만** — 사용자가 타임라인을 옮긴 뒤에는 다시
/// 당기지 않는다.
library;

/// null·0 이하·[duration] 이상이면 null(= 0초부터, 기존 동작). 그 외에는
/// 그 지점으로 seek할 [Duration].
Duration? initialClipSeek(double? playFromSec, Duration duration) {
  if (playFromSec == null || playFromSec <= 0) return null;
  if (duration <= Duration.zero) return null;
  final pos = Duration(milliseconds: (playFromSec * 1000).round());
  if (pos >= duration) return null;
  return pos;
}
