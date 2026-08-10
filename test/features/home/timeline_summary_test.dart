import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/timeline_summary.dart';
import 'package:vivananunt/features/my_cage/domain/motion_clip.dart';

MotionClip _c({required double sec, String? action}) => MotionClip(
      id: 'c-$sec-$action',
      cameraId: 'cam1',
      startedAt: DateTime(2026, 8, 5, 10),
      durationSec: sec,
      action: action,
    );

void main() {
  group('TimelineSummary.from', () {
    test('움직임 시간 = 전체 클립 duration 합', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 3600), _c(sec: 1800)],
        window: const Duration(hours: 24),
      );
      expect(s.movingSeconds, 5400);
    });

    test('휴식 시간 = 창 길이 - 움직임 시간', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 3600)],
        window: const Duration(hours: 24),
      );
      expect(s.restingSeconds, 24 * 3600 - 3600);
    });

    test('휴식은 음수가 되지 않는다', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 100000)],
        window: const Duration(hours: 24),
      );
      expect(s.restingSeconds, 0);
    });

    test('식사 횟수 — 3종 식사 액션을 합산', () {
      final s = TimelineSummary.from(
        clips: [
          _c(sec: 10, action: 'eating_paste'),
          _c(sec: 10, action: 'eating_prey'),
          _c(sec: 10, action: 'hand_feeding'),
          _c(sec: 10, action: 'drinking'),
        ],
        window: const Duration(hours: 24),
      );
      expect(s.eatCount, 3);
    });

    test('물 마신 횟수', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 5, action: 'drinking'), _c(sec: 5, action: 'drinking')],
        window: const Duration(hours: 24),
      );
      expect(s.drinkCount, 2);
    });

    test('미분류(action=null)는 어떤 횟수에도 안 들어간다', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 5), _c(sec: 5)],
        window: const Duration(hours: 24),
      );
      expect(s.eatCount, 0);
      expect(s.drinkCount, 0);
      expect(s.movingSeconds, 10);
    });

    test('빈 클립 목록 → 전부 0, 휴식은 창 전체', () {
      final s = TimelineSummary.from(
        clips: const [],
        window: const Duration(hours: 24),
      );
      expect(s.movingSeconds, 0);
      expect(s.restingSeconds, 24 * 3600);
    });
  });

  group('countByFilter — 필터 칩 활성 판정', () {
    test('해당 행동이 0건이면 0 — 칩은 Disabled', () {
      final counts = countByFilter([_c(sec: 5, action: 'drinking')]);
      expect(counts[TimelineFilter.shedding], 0);
      expect(counts[TimelineFilter.drinking], 1);
    });

    test('전체 필터는 항상 클립 총 개수', () {
      final counts =
          countByFilter([_c(sec: 5), _c(sec: 5, action: 'drinking')]);
      expect(counts[TimelineFilter.all], 2);
    });

    test('움직임 = 미분류 포함 전체 (모션 클립 자체가 움직임 근거)', () {
      final counts = countByFilter([_c(sec: 5), _c(sec: 5, action: 'moving')]);
      expect(counts[TimelineFilter.moving], 2);
    });
  });
}
