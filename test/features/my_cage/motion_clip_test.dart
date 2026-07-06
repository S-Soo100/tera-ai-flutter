import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/motion_clip.dart';

void main() {
  group('MotionClip.fromJson', () {
    test('완전한 JSON → 매핑', () {
      final c = MotionClip.fromJson({
        'id': 'mc-1',
        'camera_id': 'cam-1',
        'started_at': '2026-07-06T00:49:58Z',
        'duration_sec': 30.7,
        'motion_score': 0.05,
        'thumbnail_key': 'terra-clips/x.jpg',
      });
      expect(c.id, 'mc-1');
      expect(c.cameraId, 'cam-1');
      expect(c.durationSec, closeTo(30.7, 0.001));
      expect(c.motionScore, closeTo(0.05, 0.001));
      expect(c.startedAt.isAtSameMomentAs(DateTime.utc(2026, 7, 6, 0, 49, 58)),
          isTrue);
    });

    test('nullable(motion_score, thumbnail_key) 누락 → null', () {
      final c = MotionClip.fromJson({
        'id': 'mc-2',
        'camera_id': 'cam-1',
        'started_at': '2026-07-06T00:00:00Z',
        'duration_sec': 10,
      });
      expect(c.motionScore, isNull);
      expect(c.thumbnailKey, isNull);
    });

    test('필수 누락 → 방어적 기본값', () {
      final c = MotionClip.fromJson(<String, dynamic>{});
      expect(c.id, '');
      expect(c.cameraId, '');
      expect(c.durationSec, 0);
      expect(c.startedAt, isA<DateTime>());
    });
  });
}
