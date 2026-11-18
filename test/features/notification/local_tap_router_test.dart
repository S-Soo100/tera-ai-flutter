import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/domain/local_notification_target.dart';
import 'package:vivanaut/features/notification/domain/local_tap_router.dart';

const _mine = '4da7f48b-0000-4000-8000-111111111111';
const _other = '4da7f48b-0000-4000-8000-222222222222';
const _schedule = DeviceNotificationTarget(DeviceNotificationKind.schedule, _mine);

void main() {
  late String? user;
  late String path;
  late List<String> selected;
  late List<String> opened;
  late int loads;
  late Future<Iterable<String>> Function() devices;
  late LocalTapRouter router;

  setUp(() {
    user = 'a';
    path = '/home';
    selected = [];
    opened = [];
    loads = 0;
    devices = () async => const [_mine];
    router = LocalTapRouter(
      currentUserId: () => user,
      currentPath: () => path,
      myDeviceIds: () {
        loads++;
        return devices();
      },
      select: selected.add,
      open: opened.add,
    );
  });
  tearDown(() => router.dispose());

  test('schedule tap selects the device first, then opens routines', () async {
    router.hold(_schedule);
    await router.flush();
    expect(selected, [_mine]);
    expect(opened, ['/home/routines']);
    expect(router.hasPending, isFalse);
  });

  test('schedule tap for a device not mine goes home without selecting',
      () async {
    router.hold(
        const DeviceNotificationTarget(DeviceNotificationKind.schedule, _other));
    await router.flush();
    expect(selected, isEmpty);
    expect(opened, ['/home']);
  });

  test('schedule tap goes home when the device list cannot be read', () async {
    devices = () async => throw StateError('offline');
    router.hold(_schedule);
    await router.flush();
    expect(opened, ['/home']);
  });

  test('fan tap goes home whether or not the device is mine', () async {
    router.hold(const DeviceNotificationTarget(DeviceNotificationKind.fan, _mine));
    await router.flush();
    router.hold(
        const DeviceNotificationTarget(DeviceNotificationKind.fan, _other));
    await router.flush();
    expect(selected, [_mine]);
    expect(opened, ['/home', '/home']);
  });

  test('held while logged out, processed once signed in on a normal page',
      () async {
    user = null;
    path = '/login';
    router.hold(_schedule);
    await router.flush();
    expect(router.hasPending, isTrue);
    expect(loads, 0);
    // 로그인 직후 redirect 전(아직 /login) — 아직 처리하지 않는다.
    user = 'a';
    await router.flush();
    expect(router.hasPending, isTrue);
    path = '/home';
    await router.flush();
    expect(opened, ['/home/routines']);
    expect(router.hasPending, isFalse);
  });

  test('splash, auth pages and the forced update page keep the tap held',
      () async {
    router.hold(_schedule);
    for (final blocked in [
      '/splash',
      '/login',
      '/signup',
      '/verify-email',
      '/forgot-password',
      '/update-required',
    ]) {
      path = blocked;
      await router.flush();
      expect(router.hasPending, isTrue, reason: blocked);
    }
    expect(loads, 0);
    expect(opened, isEmpty);
    path = '/crecam';
    await router.flush();
    expect(opened, ['/home/routines']);
  });

  test('account change while the device list loads drops the tap', () async {
    final pending = Completer<Iterable<String>>();
    devices = () => pending.future;
    router.hold(_schedule);
    final work = router.flush();
    user = 'b';
    pending.complete(const [_mine]);
    await work;
    expect(selected, isEmpty);
    expect(opened, isEmpty);
    expect(router.hasPending, isFalse);
  });

  test('dispose while the device list loads drops the tap', () async {
    final pending = Completer<Iterable<String>>();
    devices = () => pending.future;
    router.hold(_schedule);
    final work = router.flush();
    router.dispose();
    pending.complete(const [_mine]);
    await work;
    expect(selected, isEmpty);
    expect(opened, isEmpty);
  });

  test('a tap arriving during processing runs after the current one',
      () async {
    final pending = Completer<Iterable<String>>();
    devices = () => pending.future;
    router.hold(_schedule);
    final work = router.flush();
    router.hold(const DeviceNotificationTarget(DeviceNotificationKind.fan, _mine));
    // 처리 중 두 번째 flush는 겹쳐 돌지 않는다.
    await router.flush();
    expect(loads, 1);
    devices = () async => const [_mine];
    pending.complete(const [_mine]);
    await work;
    await pumpEventQueue();
    expect(opened, ['/home/routines', '/home']);
  });

  test('a tap arriving while a dropped one was loading still runs (review 11-18)',
      () async {
    final gate = Completer<Iterable<String>>();
    devices = () => gate.future;
    router.hold(_schedule);
    final first = router.flush();
    await Future<void>.delayed(Duration.zero);
    // 처리 중 계정 전환 → 첫 탭은 버려진다. 그 사이 새 계정 기기의 팬 알림 탭.
    user = 'b';
    const fan = DeviceNotificationTarget(DeviceNotificationKind.fan, _mine);
    router.hold(fan);
    devices = () async => const [_mine];
    gate.complete(const [_mine]);
    await first;
    expect(router.hasPending, isFalse,
        reason: '버려진 처리 뒤에도 기다리던 탭을 이어서 처리해야 한다');
    expect(opened, ['/home']);
    expect(selected, [_mine], reason: '새 계정 기준으로 한 번만 선택');
  });

  test('the newest held tap wins', () async {
    user = null;
    router.hold(_schedule);
    router.hold(const DeviceNotificationTarget(DeviceNotificationKind.fan, _mine));
    user = 'a';
    await router.flush();
    expect(opened, ['/home']);
  });
}
