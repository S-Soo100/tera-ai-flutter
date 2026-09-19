import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';

TerraCamera _camera({
  String id = 'c1',
  String name = 'P4 Cam',
  bool isOnline = true,
  DateTime? lastSeenAt,
  String? enclosureId = 'e1',
  bool rotate180 = false,
}) =>
    TerraCamera(
      id: id,
      cameraId: 'p4cam-$id',
      name: name,
      isOnline: isOnline,
      lastSeenAt: lastSeenAt,
      enclosureId: enclosureId,
      createdAt: DateTime.utc(2026, 1, 1),
      rotate180: rotate180,
    );

void main() {
  test('생존 신호 시각만 다른 목록은 같은 목록이다', () {
    final before = [_camera(lastSeenAt: DateTime.utc(2026, 9, 19, 2, 13, 5))];
    final after = [_camera(lastSeenAt: DateTime.utc(2026, 9, 19, 2, 13, 20))];
    expect(sameCamerasIgnoringHeartbeat(before, after), isTrue);
  });

  test('화면이 쓰는 값이 바뀌면 다른 목록이다', () {
    final base = [_camera()];
    expect(sameCamerasIgnoringHeartbeat(base, [_camera(isOnline: false)]),
        isFalse);
    expect(sameCamerasIgnoringHeartbeat(base, [_camera(name: '거실')]), isFalse);
    expect(sameCamerasIgnoringHeartbeat(base, [_camera(enclosureId: 'e2')]),
        isFalse);
    expect(sameCamerasIgnoringHeartbeat(base, [_camera(rotate180: true)]),
        isFalse);
  });

  test('개수·순서가 다르면 다른 목록이다', () {
    final a = _camera(id: 'c1');
    final b = _camera(id: 'c2');
    expect(sameCamerasIgnoringHeartbeat([a], [a, b]), isFalse);
    expect(sameCamerasIgnoringHeartbeat([a, b], [b, a]), isFalse);
  });
}
