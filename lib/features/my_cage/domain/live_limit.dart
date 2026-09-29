/// 라이브 시청 제한(2026-09-30, terra-server `APP_LIVE_VIEW_LIMIT_2026-09-30.md`).
///
/// 서버가 카메라마다 **한 번에 15분·끝나면 5분 쉼·한 번에 한 기기**를 강제한다.
/// 앱은 막혔을 때 이유를 보여 주고, 사용자가 누를 때만 다시 요청한다 — 가져가기
/// 당한 쪽이 자동으로 다시 붙으면 두 기기가 서로 뺏는 루프가 된다(09-29 재연결
/// 루프로 카메라가 재부팅된 것과 같은 구조).
library;

/// 막힌 이유.
enum LiveLimitKind {
  /// 다른 기기가 보는 중(409 `live_in_use`) — "이 기기로 시청"하면 가져온다.
  inUse,

  /// 보는 중에 다른 기기가 가져갔다(cameras `live_end_reason='taken_over'`).
  takenOver,

  /// 15분을 다 봐서 쉬는 중(429 `live_cooldown` 또는 `time_limit`).
  cooldown,

  /// 시간당 연결 시도 과다(429 `rate_limited`).
  rateLimited,
}

class LiveLimit {
  const LiveLimit(this.kind, {this.viewer, this.until});

  final LiveLimitKind kind;

  /// 다른 기기 이름(inUse·takenOver). 서버가 안 주면 null.
  final String? viewer;

  /// 이 시각(폰 시계)부터 다시 볼 수 있다(cooldown·rateLimited).
  final DateTime? until;

  /// 버튼을 누를 수 있기까지 남은 시간. 없거나 지났으면 [Duration.zero].
  Duration remaining(DateTime now) {
    final u = until;
    if (u == null || !u.isAfter(now)) return Duration.zero;
    return u.difference(now);
  }
}

/// 서버 시각을 폰 시계 기준 마감으로 바꾼다. 폰 시계가 서버와 어긋나도(09-28
/// 온습도 사고) 남은 시간이 음수·과대가 되지 않게 [0, max]로 자른다.
DateTime clampServerDeadline(DateTime serverAt, DateTime now, Duration max) {
  final left = serverAt.difference(now);
  if (left.isNegative) return now;
  return left > max ? now.add(max) : serverAt;
}

/// 서버 한도 — 표시용 상한(서버가 SOT, 앱은 자르기에만 쓴다).
const kLiveMaxDuration = Duration(minutes: 15);
const kLiveCooldownDuration = Duration(minutes: 5);

/// 남은 시간이 이만큼 이하면 영상 위에 "곧 쉬어요" 알약(2026-09-30 사용자 결정).
const kLiveEndingSoon = Duration(minutes: 1);

/// cameras 행의 라이브 세션 컬럼(보고 있는 카메라만 Realtime으로 받는다).
class CameraLiveSession {
  const CameraLiveSession({
    this.sessionId,
    this.viewer,
    this.endReason,
    this.cooldownUntil,
  });

  /// 지금 시청 중인 WebRTC session_id. 끝났으면 null.
  final String? sessionId;

  /// 지금(또는 마지막) 시청 기기 이름.
  final String? viewer;

  /// `time_limit` | `taken_over` | `closed` | `failed`.
  final String? endReason;
  final DateTime? cooldownUntil;

  /// 컬럼이 없는 구 DB면 모두 null — 아무 판정도 하지 않는다.
  factory CameraLiveSession.fromRow(Map<String, dynamic> row) {
    String? text(String k) {
      final v = row[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    final cooldown = text('live_cooldown_until');
    return CameraLiveSession(
      sessionId: text('live_session_id'),
      viewer: text('live_viewer'),
      endReason: text('live_end_reason'),
      cooldownUntil: cooldown == null ? null : DateTime.tryParse(cooldown),
    );
  }

  /// 내 세션([mySessionId])이 이 행 변경으로 끝났는지. 아니면 null.
  ///
  /// - 다른 세션이 들어왔고 `taken_over` → 가져가짐
  /// - 세션이 비었고 `time_limit` → 15분 끝(쉼)
  /// 그 밖의 변화(생존 신호·내가 닫음·연결 실패)는 기존 흐름에 맡긴다.
  LiveLimit? endedFor(String mySessionId, DateTime now) {
    final sid = sessionId;
    if (sid == mySessionId) return null;
    if (sid != null && endReason == 'taken_over') {
      return LiveLimit(LiveLimitKind.takenOver, viewer: viewer);
    }
    if (sid == null && endReason == 'time_limit') {
      final c = cooldownUntil;
      return LiveLimit(LiveLimitKind.cooldown,
          until: c == null
              ? now.add(kLiveCooldownDuration)
              : clampServerDeadline(c, now, kLiveCooldownDuration));
    }
    return null;
  }
}
