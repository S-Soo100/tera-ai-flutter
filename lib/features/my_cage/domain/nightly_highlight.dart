import '../../../shared/domain/num_format.dart';

/// petcam-api GET /highlights 항목(보기 전용). clip_id=motion_clips.id(미러)라
/// 썸네일(motionThumbnailProvider)·재생(MotionClipPlayerScreen) 재사용.
///
/// 하이라이트는 자동 O/X 규칙([ruleVersion], 몇 주간 사람이 튜닝)이 1차 판정하고
/// 사람 확정([source] == 'human')이 덮어쓴다(2026-09-08). VLM 행동 라벨·신뢰도·
/// care_level은 계약에서 빠졌다.
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

  /// 사람이 확정한 시각. 자동 판정이면 null.
  final DateTime? decidedAt;

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
  });

  bool get isHumanConfirmed => source == 'human';

  factory NightlyHighlight.fromJson(Map<String, dynamic> j) {
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
    );
  }
}
