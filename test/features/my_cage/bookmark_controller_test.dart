import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmark_controller.dart';

void main() {
  test('아이콘은 즉시 바뀌고 추가 중 해제는 마지막 의도로 저장한다', () async {
    final pending = Completer<void>();
    final writes = <bool>[];
    final controller = BookmarkController(
        initial: false,
        persist: (value) async {
          writes.add(value);
          if (writes.length == 1) await pending.future;
        });
    addTearDown(controller.dispose);
    controller.setDesired(true);
    expect(controller.state.desired, true);
    controller.setDesired(false);
    expect(controller.state.desired, false);
    pending.complete();
    await controller.settled;
    expect(writes, [true, false]);
    expect(controller.state.persisted, false);
    expect(controller.state.saving, false);
  });
  test('추가 해제 추가 연타는 불필요한 삭제 없이 최종 추가를 보존한다', () async {
    final pending = Completer<void>();
    final writes = <bool>[];
    final controller = BookmarkController(
        initial: false,
        persist: (value) async {
          writes.add(value);
          await pending.future;
        });
    addTearDown(controller.dispose);
    controller.setDesired(true);
    controller.setDesired(false);
    controller.setDesired(true);
    pending.complete();
    await controller.settled;
    expect(writes, [true]);
    expect(controller.state.desired, true);
  });
  test('영구 실패는 실제 저장 상태로 복구하고 재시도할 수 있다', () async {
    var fail = true;
    final controller = BookmarkController(
        initial: false,
        persist: (value) async {
          if (fail) throw StateError('disk full');
        });
    addTearDown(controller.dispose);
    controller.setDesired(true);
    await controller.settled;
    expect(controller.state.desired, false);
    expect(controller.state.error, isNotNull);
    fail = false;
    controller.retry();
    await controller.settled;
    expect(controller.state.desired, true);
    expect(controller.state.error, isNull);
  });
}
