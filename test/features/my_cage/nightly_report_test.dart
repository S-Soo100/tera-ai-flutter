import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_highlight.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_report.dart';

NightlyHighlight h(String a) => NightlyHighlight(
    clipId: a, startedAt: DateTime(2026, 7, 7, 23), vlmAction: a,
    confidence: 0.7, careLevel: 'care');

void main() {
  test('행동 카운트 분류', () {
    final r = NightlyReport(activitySeconds: 3600, highlights: [
      h('drinking'), h('drinking'),
      h('hand_feeding'), h('eating_paste'), h('eating_prey'),
      h('shedding'),
      h('unseen'),
    ]);
    expect(r.drinkCount, 2);
    expect(r.eatCount, 3); // hand_feeding+eating_paste+eating_prey
    expect(r.shedCount, 1);
    expect(r.activityMinutes, 60);
  });
}
