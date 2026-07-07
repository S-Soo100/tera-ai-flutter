import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/presentation/widgets/video_controls.dart';

void main() {
  group('formatClipPosition', () {
    test('0초 → 0:00', () {
      expect(formatClipPosition(Duration.zero), '0:00');
    });
    test('9초 → 0:09 (초 2자리 패딩)', () {
      expect(formatClipPosition(const Duration(seconds: 9)), '0:09');
    });
    test('75초 → 1:15', () {
      expect(formatClipPosition(const Duration(seconds: 75)), '1:15');
    });
    test('600초 → 10:00', () {
      expect(formatClipPosition(const Duration(minutes: 10)), '10:00');
    });
  });
}
