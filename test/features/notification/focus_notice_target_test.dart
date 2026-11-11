import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/domain/focus_notice_target.dart';

void main() {
  test('선택된 카메라가 내 목록에 있으면 그 상세', () {
    expect(
        focusNoticeCameraPath(myCameraIds: ['a', 'b'], selectedCameraId: 'b'),
        '/crecam/cameras/b/live');
  });

  test('선택이 없거나 목록에 없으면 첫 카메라 상세', () {
    expect(
        focusNoticeCameraPath(myCameraIds: ['a', 'b'], selectedCameraId: 'z'),
        '/crecam/cameras/a/live');
    expect(focusNoticeCameraPath(myCameraIds: ['a'], selectedCameraId: null),
        '/crecam/cameras/a/live');
  });

  test('카메라가 없으면 null(호출한 쪽이 카메라 탭으로 go)', () {
    expect(
        focusNoticeCameraPath(myCameraIds: [], selectedCameraId: null), isNull);
  });

  test('안내가 카메라를 가리키면 고른 카메라와 상관없이 그 카메라 상세', () {
    expect(
        focusNoticeCameraPath(
            myCameraIds: ['a', 'b'],
            selectedCameraId: 'a',
            targetCameraId: 'b'),
        '/crecam/cameras/b/live');
  });

  test('가리키는 카메라가 내 목록에 없으면 null', () {
    expect(
        focusNoticeCameraPath(
            myCameraIds: ['a'], selectedCameraId: 'a', targetCameraId: 'gone'),
        isNull);
  });
}
