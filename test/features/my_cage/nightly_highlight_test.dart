import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_highlight.dart';

void main() {
  Map<String, dynamic> base(Object? uc) => {
        'clip_id': 'c1',
        'started_at': '2026-07-07T13:07:00Z',
        'thumbnail_key': 'terra-clips/clips/x.jpg',
        'vlm_action': 'drinking',
        'confidence': 0.62,
        'care_level': 'care',
        'user_confirmed': uc,
      };

  group('NightlyHighlight.fromJson', () {
    test('user_confirmed=null → pending', () {
      final h = NightlyHighlight.fromJson(base(null));
      expect(h.clipId, 'c1');
      expect(h.vlmAction, 'drinking');
      expect(h.careLevel, 'care');
      expect(h.confidence, closeTo(0.62, 0.001));
      expect(h.review, HighlightReview.pending);
      expect(h.correctedAction, isNull);
    });
    test('user_confirmed=true → confirmed', () {
      expect(NightlyHighlight.fromJson(base(true)).review,
          HighlightReview.confirmed);
    });
    test('user_confirmed=false → pending(저장 안 된 상태로 취급)', () {
      expect(NightlyHighlight.fromJson(base(false)).review,
          HighlightReview.pending);
    });
    test('user_confirmed=문자열 → corrected + 정정action', () {
      final h = NightlyHighlight.fromJson(base('hand_feeding'));
      expect(h.review, HighlightReview.corrected);
      expect(h.correctedAction, 'hand_feeding');
    });
  });
}
