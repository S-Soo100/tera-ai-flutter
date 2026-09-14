import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vivanaut/shared/services/local_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'concurrent initialization installs one callback and both remote channels; taps stay configurable',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {
          'notificationLaunchedApp': true,
          'notificationResponse': {
            'notificationResponseType': 0,
            'payload': 'cold'
          }
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final core = LocalNotifications.instance;
    final taps = <String>[];
    core.onTap = taps.add;
    await Future.wait([core.ensureInitialized(), core.ensureInitialized()]);
    expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
    final channels = calls
        .where((c) => c.method == 'createNotificationChannel')
        .map((c) => (c.arguments as Map<Object?, Object?>)['id']);
    expect(channels, containsAll(['vivanaut_default', 'vivanaut_safety']));
    await core.deliverInitialTap();
    await core.deliverInitialTap();
    expect(taps, ['cold']);
    core.onTap = (payload) => taps.add('new:$payload');
    await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('didReceiveNotificationResponse', {
          'notificationResponseType': 0,
          'payload': 'warm',
        })),
        (_) {});
    expect(taps, ['cold', 'new:warm']);
    await core.showRemote(
        id: -42, title: '제목', body: '본문', safety: true, payload: 'payload');
    final show = calls.lastWhere((c) => c.method == 'show').arguments
        as Map<Object?, Object?>;
    expect(show['id'], -42);
    expect(show['payload'], 'payload');
    expect((show['platformSpecifics'] as Map<Object?, Object?>)['channelId'],
        'vivanaut_safety');
  });
}
