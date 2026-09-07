import '../../my_cage/domain/motion_clip.dart';

/// PRD §3.5 이벤트 필터 칩. 0건이어도 **사라지지 않고 Disabled로 고정 노출**된다.
enum TimelineFilter { all, moving, eating, drinking, shedding }

/// PRD §3.5 당일 요약 칩 — 움직임/휴식 시간, 식사/물 마신 횟수.
///
/// 행동 분류는 `behavior_logs`(BE5)에 의존한다. 라벨이 없으면 전부 미분류라
/// 식사·물마심 횟수가 0인 게 정상 — 이건 버그가 아니라 백엔드 대기 상태다.
class TimelineSummary {
  final int movingSeconds;
  final int restingSeconds;
  final int eatCount;
  final int drinkCount;

  const TimelineSummary({
    required this.movingSeconds,
    required this.restingSeconds,
    required this.eatCount,
    required this.drinkCount,
  });

  static const eatActions = {'eating_paste', 'eating_prey', 'hand_feeding'};

  factory TimelineSummary.from({
    required List<MotionClip> clips,
    required Duration window,
  }) {
    final moving =
        clips.fold<double>(0, (sum, c) => sum + c.durationSec).round();
    final resting = window.inSeconds - moving;
    return TimelineSummary(
      movingSeconds: moving,
      // 감지 표본이 창을 넘길 수 있다(중복 구간). 음수 휴식은 의미가 없다.
      restingSeconds: resting < 0 ? 0 : resting,
      eatCount: clips.where((c) => eatActions.contains(c.action)).length,
      drinkCount: clips.where((c) => c.action == 'drinking').length,
    );
  }
}

/// 필터별 건수. 0인 필터의 칩은 Disabled로 그린다.
///
/// `moving`은 미분류 클립까지 포함한다 — 모션 클립이 존재한다는 사실 자체가
/// 움직임의 근거이기 때문(분류는 그 위에 얹히는 정보다).
Map<TimelineFilter, int> countByFilter(List<MotionClip> clips) {
  return {
    TimelineFilter.all: clips.length,
    TimelineFilter.moving: clips.length,
    TimelineFilter.eating: clips
        .where((c) => TimelineSummary.eatActions.contains(c.action))
        .length,
    TimelineFilter.drinking: clips.where((c) => c.action == 'drinking').length,
    TimelineFilter.shedding: clips.where((c) => c.action == 'shedding').length,
  };
}
