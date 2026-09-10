import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_highlight.dart';

void main() {
  test('NightlyHighlight.fromJson 매핑 (petcam-api /highlights 계약)', () {
    final h = NightlyHighlight.fromJson({
      'clip_id': 'c1',
      'camera_id': 'cam1',
      'camera_name': '거실',
      'started_at': '2026-07-07T13:07:00Z',
      'duration_sec': 42.5,
      'source': 'human',
      'reason': '움직임 12.4초 · 최장 연속 6.1초',
      'rule_version': 'hl-rule-v0',
      'decided_at': '2026-07-08T01:00:00Z',
    });
    expect(h.clipId, 'c1');
    expect(h.cameraId, 'cam1');
    expect(h.cameraName, '거실');
    expect(h.startedAt.toUtc(), DateTime.utc(2026, 7, 7, 13, 7));
    expect(h.durationSec, closeTo(42.5, 0.001));
    expect(h.source, 'human');
    expect(h.isHumanConfirmed, isTrue);
    expect(h.reason, '움직임 12.4초 · 최장 연속 6.1초');
    expect(h.ruleVersion, 'hl-rule-v0');
    expect(h.decidedAt?.toUtc(), DateTime.utc(2026, 7, 8, 1));
  });
  test('rule 소스 + decided_at null', () {
    final h = NightlyHighlight.fromJson({
      'clip_id': 'c2',
      'started_at': '2026-07-07T13:07:00Z',
      'source': 'rule',
      'reason': '움직임 3.0초',
      'decided_at': null,
    });
    expect(h.isHumanConfirmed, isFalse);
    expect(h.decidedAt, isNull);
  });
  test('필드 누락 → 방어 기본값', () {
    final h = NightlyHighlight.fromJson(<String, dynamic>{});
    expect(h.clipId, '');
    expect(h.cameraId, '');
    expect(h.cameraName, '');
    expect(h.durationSec, 0);
    expect(h.source, 'rule');
    expect(h.isHumanConfirmed, isFalse);
    expect(h.reason, '');
    expect(h.ruleVersion, '');
    expect(h.decidedAt, isNull);
  });

  test('/highlights/featured 응답 → tier·day_key·episode 파싱', () {
    final h = NightlyHighlight.fromJson({
      'clip_id': 'c3',
      'camera_id': 'cam1',
      'camera_name': '거실',
      'started_at': '2026-09-08T21:00:00Z',
      'duration_sec': 30,
      'media_ready': true,
      'source': 'rule',
      'reason': '움직임 84.0초',
      'rule_version': 'hl-rule-v0',
      'tier': 'featured',
      'day_key': '2026-09-08',
      'activity_sec': 84.2,
      'behavior_flagged': true,
      'episode': {
        'rank': 1,
        'clip_count': 6,
        'activity_sec': 120.5,
        'started_at': '2026-09-08T20:58:00Z',
        'ended_at': '2026-09-08T21:10:00Z',
      },
    });
    expect(h.tier, 'featured');
    expect(h.isFeatured, isTrue);
    expect(h.dayKey, '2026-09-08');
    expect(h.activitySec, closeTo(84.2, 0.001));
    expect(h.behaviorFlagged, isTrue);
    expect(h.episodeRank, 1);
    expect(h.episodeClipCount, 6);
    expect(h.episodeActivitySec, closeTo(120.5, 0.001));
    expect(h.episodeStartedAt?.toUtc(), DateTime.utc(2026, 9, 8, 20, 58));
    expect(h.episodeEndedAt?.toUtc(), DateTime.utc(2026, 9, 8, 21, 10));
    // 이 응답에는 decided_at이 없다(계약 2026-09-11) → null.
    expect(h.decidedAt, isNull);
  });

  test('구 /highlights 응답(새 키 없음) → featured 기본값 호환', () {
    final h = NightlyHighlight.fromJson({
      'clip_id': 'c1',
      'started_at': '2026-09-07T14:00:00Z',
      'source': 'rule',
    });
    expect(h.tier, '');
    expect(h.isFeatured, isFalse);
    expect(h.dayKey, '');
    expect(h.activitySec, 0);
    expect(h.behaviorFlagged, isFalse);
    expect(h.episodeRank, 0);
    expect(h.episodeClipCount, 0);
    expect(h.episodeActivitySec, 0);
    expect(h.episodeStartedAt, isNull);
    expect(h.episodeEndedAt, isNull);
  });
}
