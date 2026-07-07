/// 사육 하루의 시작 시각(오전 7시). 야행성 파충류의 밤 활동을 한 하루로 묶기
/// 위한 경계. 안내 문구(`crecam_detail_activity_baseline`)와 함께 유지한다.
const int kCageDayStartHour = 7;

/// 활동량 카드의 하루 집계 범위 (오전 7시 기준).
enum ActivityRange { yesterday, today }

/// 카메라 하루(오전 7시 기준) 활동량 요약.
///
/// - [motionSeconds]: 움직임(모션 감지) 녹화 시간 합계 — `camera_clips.has_motion`
///   클립의 `duration_sec` 합.
/// - [drinkingClips]: 음수 행동이 담긴 클립 수 (distinct clip).
/// - [feedingClips]: 식사(페이스트/먹이/핸드피딩) 행동이 담긴 클립 수 (distinct clip).
class CageActivity {
  final int motionSeconds;
  final int drinkingClips;
  final int feedingClips;

  const CageActivity({
    required this.motionSeconds,
    required this.drinkingClips,
    required this.feedingClips,
  });

  static const empty =
      CageActivity(motionSeconds: 0, drinkingClips: 0, feedingClips: 0);
}

/// behavior_logs.action 중 '식사 접근'으로 집계할 값들.
const Set<String> kFeedingActions = {
  'eating_paste',
  'eating_prey',
  'hand_feeding',
};

/// behavior_logs.action 중 '음수'로 집계할 값.
const String kDrinkingAction = 'drinking';

/// 오전 7시(07:00) 기준 하루 경계. `[start, end)` 로컬 시각을 반환한다.
///
/// - today: 가장 최근 07:00 경계부터 다음 07:00까지 (진행 중인 하루).
/// - yesterday: 그 직전 24시간.
///
/// 예) now=2026-07-03 05:00 → 아직 오전 7시 전이므로 '오늘'은
///     2026-07-02 07:00 ~ 2026-07-03 07:00.
({DateTime start, DateTime end}) activityRangeBounds(
    ActivityRange range, DateTime now) {
  // 벽시계 기준 오전 7시 경계. `add(Duration(days:1))`은 절대 24h라 DST
  // 타임존에서 07:00이 06:00/08:00로 밀린다. DateTime 생성자로 벽시계 07:00을
  // 직접 만들고(생성자가 day 오버/언더플로를 자동 정규화) DST에 견고하게 한다.
  DateTime dayStartOn(DateTime d, int dayOffset) =>
      DateTime(d.year, d.month, d.day + dayOffset, kCageDayStartHour);

  var todayStart = dayStartOn(now, 0);
  if (now.isBefore(todayStart)) {
    todayStart = dayStartOn(now, -1); // 아직 오전 7시 전 → 전날 07:00이 시작
  }
  switch (range) {
    case ActivityRange.today:
      return (start: todayStart, end: dayStartOn(todayStart, 1));
    case ActivityRange.yesterday:
      return (start: dayStartOn(todayStart, -1), end: todayStart);
  }
}

/// 하루(24시간) 활동을 1시간 버킷 24개로 집계한다. 홈·크레캠의 시간대별 활동
/// 그래프 공용 데이터.
///
/// - 반환 길이는 항상 24. index i = [from]으로부터 i시간째 구간 `[from+i, from+i+1)`.
///   하루 경계가 07:00이면 index 0 = 07~08시, index 23 = 익일 06~07시.
/// - 각 클립은 **시작 시각**이 속한 버킷에 duration 전량 귀속(1시간 경계를 걸치는
///   클립도 시작 버킷에 몰아줌 — 근사). 0~23 밖(시작 전/24h 이상)은 무시.
/// - 절대 시각(instant) 차로 계산하므로 startedAt이 UTC/로컬 어느 표현이든
///   [from]이 로컬 벽시계 07:00이면 결과는 로컬 시간대 기준으로 정확하다.
List<int> bucketMotionSecondsByHour(
  Iterable<({DateTime startedAt, double durationSec})> clips,
  DateTime from,
) {
  final buckets = List<double>.filled(24, 0);
  for (final c in clips) {
    // isBefore로 하한을 명시(Duration.inHours는 0 방향 절삭이라 from 직전
    // 몇 분 클립이 -1분→0시간으로 버킷 0에 새는 걸 막는다).
    if (c.startedAt.isBefore(from)) continue;
    final idx = c.startedAt.difference(from).inHours;
    if (idx > 23) continue;
    buckets[idx] += c.durationSec;
  }
  return buckets.map((s) => s.round()).toList();
}
