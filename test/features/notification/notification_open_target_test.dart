import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';
import 'package:vivanaut/features/notification/domain/notification_open_target.dart';

AppNotification _item(String kind, {Object? deviceId = 'dev-2'}) =>
    AppNotification.fromJson({
      'id': 'n1',
      'user_id': 'u1',
      'kind': kind,
      'category': kind.split('.').first,
      'route': '/env-detail',
      'data': <String, Object?>{
        if (deviceId != null) 'device_id': deviceId,
      },
    });

void main() {
  late List<String> selected;
  late int loads;
  setUp(() {
    selected = [];
    loads = 0;
  });

  Future<Iterable<String>> mine() async {
    loads++;
    return const ['dev-1', 'dev-2'];
  }

  test('env alert switches the home device when it is one of mine', () async {
    final done = await selectNotificationDevice(
        _item('env.alert.triggered').targetDeviceId,
        myDeviceIds: mine,
        select: selected.add);
    expect(selected, ['dev-2']);
    expect(done, isTrue);
  });

  test('env alert for a device not in my list leaves the selection alone',
      () async {
    final done = await selectNotificationDevice(
        _item('env.alert.triggered', deviceId: 'someone-else').targetDeviceId,
        myDeviceIds: mine,
        select: selected.add);
    expect(selected, isEmpty);
    expect(done, isFalse);
  });

  test('other kinds and missing device ids never load the device list',
      () async {
    final results = [
      await selectNotificationDevice(_item('safety.alert').targetDeviceId,
          myDeviceIds: mine, select: selected.add),
      await selectNotificationDevice(
          _item('env.alert.triggered', deviceId: null).targetDeviceId,
          myDeviceIds: mine,
          select: selected.add),
    ];
    expect(loads, 0);
    expect(selected, isEmpty);
    expect(results, [false, false]);
  });

  test('device list failure or timeout keeps the selection and does not throw',
      () async {
    final failed = await selectNotificationDevice('dev-2',
        myDeviceIds: () async => throw StateError('offline'),
        select: selected.add);
    final never = Completer<Iterable<String>>();
    final timedOut = await selectNotificationDevice('dev-2',
        myDeviceIds: () => never.future,
        select: selected.add,
        timeout: const Duration(milliseconds: 10));
    expect(selected, isEmpty);
    expect([failed, timedOut], [false, false]);
  });

  test('any device id works — local schedule and fan taps reuse this',
      () async {
    expect(
        await selectNotificationDevice('dev-1',
            myDeviceIds: mine, select: selected.add),
        isTrue);
    expect(selected, ['dev-1']);
  });
}
