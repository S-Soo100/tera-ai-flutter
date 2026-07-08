import 'nightly_highlight.dart';

/// 어젯밤(22~06시) 요약 = 활동 시간 + 하이라이트 목록 + 행동 카운트(파생).
/// 카운트는 AI 샘플 감지분(전수 아님).
class NightlyReport {
  final int activitySeconds; // 밤 구간 motion_clips duration 합(전 카메라)
  final List<NightlyHighlight> highlights;

  const NightlyReport(
      {required this.activitySeconds, required this.highlights});

  static const _eat = {'hand_feeding', 'eating_paste', 'eating_prey'};

  int get activityMinutes => (activitySeconds / 60).round();
  int _count(bool Function(String) f) =>
      highlights.where((h) => f(h.vlmAction)).length;
  int get drinkCount => _count((a) => a == 'drinking');
  int get eatCount => _count(_eat.contains);
  int get shedCount => _count((a) => a == 'shedding');
  bool get isQuiet => highlights.isEmpty;
}
