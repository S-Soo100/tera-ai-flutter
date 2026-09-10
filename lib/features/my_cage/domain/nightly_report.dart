import 'nightly_highlight.dart';

/// 어젯밤 요약 = 활동 시간(22~06시) + ⭐ 대표 하이라이트 목록 + 후보 수.
/// 행동별 카운트(물/밥/탈피)는 하이라이트가 자동 규칙+사람 확정으로 바뀌면서
/// (2026-09-08) 제거됐다 — 이제 행동 라벨이 없다.
///
/// 2026-09-11: [highlights]는 어젯밤 day_key(20:00 경계)의 **대표(featured,
/// 0~top_n개)만** 담는다. 나머지 후보는 [candidateCount]로 개수만 보인다.
class NightlyReport {
  final int activitySeconds; // 밤 구간 motion_clips duration 합(전 카메라)
  final List<NightlyHighlight> highlights;
  final int candidateCount;

  const NightlyReport({
    required this.activitySeconds,
    required this.highlights,
    this.candidateCount = 0,
  });

  int get activityMinutes => (activitySeconds / 60).round();
  int get highlightCount => highlights.length;
  bool get isQuiet => highlights.isEmpty;
}
