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
    await selectNotificationDevice(_item('env.alert.triggered'),
        myDeviceIds: mine, select: selected.add);
    expect(selected, ['dev-2']);
  });

  test('env alert for a device not in my list leaves the selection alone',
      () async {
    await selectNotificationDevice(
        _item('env.alert.triggered', deviceId: 'someone-else'),
        myDeviceIds: mine,
        select: selected.add);
    expect(selected, isEmpty);
  });

  test('other kinds and missing device ids never load the device list',
      () async {
    await selectNotificationDevice(_item('safety.alert'),
        myDeviceIds: mine, select: selected.add);
    await selectNotificationDevice(_item('env.alert.triggered', deviceId: null),
        myDeviceIds: mine, select: selected.add);
    expect(loads, 0);
    expect(selected, isEmpty);
  });

  test('device list failure or timeout keeps the selection and does not throw',
      () async {
    await selectNotificationDevice(_item('env.alert.triggered'),
        myDeviceIds: () async => throw StateError('offline'),
        select: selected.add);
    final never = Completer<Iterable<String>>();
    await selectNotificationDevice(_item('env.alert.triggered'),
        myDeviceIds: () => never.future,
        select: selected.add,
        timeout: const Duration(milliseconds: 10));
    expect(selected, isEmpty);
  });
}
