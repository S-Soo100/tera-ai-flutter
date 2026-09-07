import 'nightly_highlight.dart';

/// 어젯밤(22~06시) 요약 = 활동 시간 + 하이라이트 목록.
/// 행동별 카운트(물/밥/탈피)는 하이라이트가 자동 규칙+사람 확정으로 바뀌면서
/// (2026-09-08) 제거됐다 — 이제 행동 라벨이 없다. 하이라이트 개수만 센다.
class NightlyReport {
  final int activitySeconds; // 밤 구간 motion_clips duration 합(전 카메라)
  final List<NightlyHighlight> highlights;

  const NightlyReport(
      {required this.activitySeconds, required this.highlights});

  int get activityMinutes => (activitySeconds / 60).round();
  int get highlightCount => highlights.length;
  bool get isQuiet => highlights.isEmpty;
}
