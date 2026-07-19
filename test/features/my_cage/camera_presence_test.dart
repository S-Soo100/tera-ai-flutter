import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/camera_presence.dart';

void main() {
  final now = DateTime.utc(2026, 7, 19, 12, 0);

  test('오프라인이면 last_seen과 무관하게 offline', () {
    expect(
      cameraPresence(isOnline: false, lastSeenAt: now, now: now),
      CameraPresence.offline,
    );
  });

  test('온라인 + last_seen 5분 이내면 online', () {
    expect(
      cameraPresence(
        isOnline: true,
        lastSeenAt: now.subtract(const Duration(minutes: 3)),
        now: now,
      ),
      CameraPresence.online,
    );
  });

  test('온라인이어도 last_seen 5분 초과면 stale', () {
    expect(
      cameraPresence(
        isOnline: true,
        lastSeenAt: now.subtract(const Duration(minutes: 6)),
        now: now,
      ),
      CameraPresence.stale,
    );
  });

  test('last_seen null이면 서버 판정(online)을 신뢰', () {
    expect(
      cameraPresence(isOnline: true, lastSeenAt: null, now: now),
      CameraPresence.online,
    );
  });
}
