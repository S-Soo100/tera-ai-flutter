import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_report.dart';

NightlyHighlight h(String id, {String source = 'rule'}) => NightlyHighlight(
    clipId: id, startedAt: DateTime(2026, 7, 7, 23), source: source);

void main() {
  test('하이라이트 개수 + 활동 분', () {
    final r = NightlyReport(activitySeconds: 3600, highlights: [
      h('a'),
      h('b', source: 'human'),
      h('c'),
    ]);
    expect(r.highlightCount, 3);
    expect(r.isQuiet, isFalse);
    expect(r.activityMinutes, 60);
  });
  test('하이라이트 없음 → 조용한 밤', () {
    const r = NightlyReport(activitySeconds: 90, highlights: []);
    expect(r.highlightCount, 0);
    expect(r.isQuiet, isTrue);
    expect(r.activityMinutes, 2);
  });
}
