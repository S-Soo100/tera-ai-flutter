import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';

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
        'action': 'moving',
      });
      expect(c.id, 'mc-1');
      expect(c.cameraId, 'cam-1');
      expect(c.durationSec, closeTo(30.7, 0.001));
      expect(c.motionScore, closeTo(0.05, 0.001));
      expect(c.action, 'moving');
      expect(c.startedAt.isAtSameMomentAs(DateTime.utc(2026, 7, 6, 0, 49, 58)),
          isTrue);
    });

    test('started_at(UTC timestamptz)은 로컬 시각으로 파싱된다 — 표시·날짜 경계가 9시간 어긋나지 않게',
        () {
      // 실기기 버그(2026-08-19): Supabase `started_at`이 `+00:00`으로 와서
      // DateTime.tryParse가 UTC 객체를 만들고, DateFormat('HH:mm')이 그 UTC
      // 시각을 그대로 찍어 한국에서 9시간 빠르게 보였다. 도메인 객체는
      // **로컬**이어야 표시도, 07:00 하루 경계 비교도 맞는다.
      final c = MotionClip.fromJson({
        'id': 'mc-2',
        'camera_id': 'cam-1',
        'started_at': '2026-08-19T09:12:53+00:00',
        'duration_sec': 10.0,
      });
      expect(c.startedAt.isUtc, isFalse, reason: '파싱 결과는 로컬 시각이어야 한다');
      // 순간은 동일 — 로컬로 바꿔도 시점이 달라지면 안 된다.
      expect(c.startedAt.isAtSameMomentAs(DateTime.utc(2026, 8, 19, 9, 12, 53)),
          isTrue);
      // 표시 포맷은 기기 로컬 시각을 찍는다(테스트 환경 오프셋에 무관하게 검증).
      final expectedLocal = DateTime.utc(2026, 8, 19, 9, 12, 53).toLocal();
      expect(c.startedAt.hour, expectedLocal.hour);
      expect(c.startedAt.minute, expectedLocal.minute);
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
      expect(c.action, isNull);
      expect(c.startedAt, isA<DateTime>());
    });
  });
}
