import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_highlight.dart';

void main() {
  test('NightlyHighlight.fromJson 매핑', () {
    final h = NightlyHighlight.fromJson({
      'clip_id': 'c1',
      'started_at': '2026-07-07T13:07:00Z',
      'vlm_action': 'drinking',
      'confidence': 0.62,
      'care_level': 'care',
    });
    expect(h.clipId, 'c1');
    expect(h.vlmAction, 'drinking');
    expect(h.careLevel, 'care');
    expect(h.confidence, closeTo(0.62, 0.001));
  });
  test('필드 누락 → 방어 기본값', () {
    final h = NightlyHighlight.fromJson(<String, dynamic>{});
    expect(h.clipId, '');
    expect(h.vlmAction, 'unseen');
    expect(h.careLevel, 'care');
  });
}
