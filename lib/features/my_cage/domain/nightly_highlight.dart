import '../../../shared/domain/num_format.dart';

/// petcam-api GET /highlights·/highlights/featured 항목(보기 전용).
/// clip_id=motion_clips.id(미러)라 썸네일(motionThumbnailProvider)·재생
/// (MotionClipPlayerScreen) 재사용.
///
/// 하이라이트는 자동 O/X 규칙([ruleVersion], 몇 주간 사람이 튜닝)이 1차 판정하고
/// 사람 확정([source] == 'human')이 덮어쓴다(2026-09-08). 2026-09-11부터
/// `/highlights/featured`가 하루(20:00 KST 경계, [dayKey]) 단위로 ⭐ 대표
/// ([tier] == 'featured', 카메라당 최대 top_n개)와 나머지 후보를 계산해 준다 —
/// 저장값이 아니라 조회 시 계산이므로 앱은 오래 캐시하지 않는다.
class NightlyHighlight {
  final String clipId;
  final String cameraId;
  final String cameraName;
  final DateTime startedAt;
  final double durationSec;

  /// 'human'(사람 확정) | 'rule'(자동 규칙).
  final String source;

  /// 판정 사유 문구(예: "움직임 12.4초 · 최장 연속 6.1초"). 배지 텍스트로 쓴다.
  final String reason;
  final String ruleVersion;

  /// 사람이 확정한 시각. 자동 판정이면 null. `/highlights/featured` 응답에는
  /// 없어 항상 null이다(계약 2026-09-11).
  final DateTime? decidedAt;

  /// 'featured'(하루 대표) | 'candidate'(후보). 구 `/highlights` 응답에는
  /// 없다 → ''(대표 아님).
  final String tier;

  /// 그 하루의 시작 날짜 "YYYY-MM-DD" (20:00 KST 경계 — 09-08 21:00과
  /// 09-09 05:00은 둘 다 "2026-09-08"). 구 응답에는 없다 → ''.
  final String dayKey;

  /// 클립 자체의 움직임 시간(초).
  final double activitySec;

  /// 라벨러가 ✨ 의미있는 행동으로 체크한 클립.
  final bool behaviorFlagged;

  /// 에피소드(연속 움직임 묶음) 메타 — 그 하루·카메라 안 순위 등.
  /// 구 응답에는 없다 → 0/null.
  final int episodeRank;
  final int episodeClipCount;
  final double episodeActivitySec;
  final DateTime? episodeStartedAt;
  final DateTime? episodeEndedAt;

  const NightlyHighlight({
    required this.clipId,
    required this.startedAt,
    this.cameraId = '',
    this.cameraName = '',
    this.durationSec = 0,
    this.source = 'rule',
    this.reason = '',
    this.ruleVersion = '',
    this.decidedAt,
    this.tier = '',
    this.dayKey = '',
    this.activitySec = 0,
    this.behaviorFlagged = false,
    this.episodeRank = 0,
    this.episodeClipCount = 0,
    this.episodeActivitySec = 0,
    this.episodeStartedAt,
    this.episodeEndedAt,
  });

  bool get isHumanConfirmed => source == 'human';
  bool get isFeatured => tier == 'featured';

  factory NightlyHighlight.fromJson(Map<String, dynamic> j) {
    final episode = j['episode'] is Map<String, dynamic>
        ? j['episode'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return NightlyHighlight(
      clipId: j['clip_id'] as String? ?? '',
      cameraId: j['camera_id'] as String? ?? '',
      cameraName: j['camera_name'] as String? ?? '',
      startedAt: parseLocalDateTime(j['started_at']) ?? DateTime.now(),
      durationSec: (j['duration_sec'] as num?)?.toDouble() ?? 0,
      source: j['source'] as String? ?? 'rule',
      reason: j['reason'] as String? ?? '',
      ruleVersion: j['rule_version'] as String? ?? '',
      decidedAt: parseLocalDateTime(j['decided_at']),
      tier: j['tier'] as String? ?? '',
      dayKey: j['day_key'] as String? ?? '',
      activitySec: (j['activity_sec'] as num?)?.toDouble() ?? 0,
      behaviorFlagged: j['behavior_flagged'] as bool? ?? false,
      episodeRank: (episode['rank'] as num?)?.toInt() ?? 0,
      episodeClipCount: (episode['clip_count'] as num?)?.toInt() ?? 0,
      episodeActivitySec: (episode['activity_sec'] as num?)?.toDouble() ?? 0,
      episodeStartedAt: parseLocalDateTime(episode['started_at']),
      episodeEndedAt: parseLocalDateTime(episode['ended_at']),
    );
  }
}
