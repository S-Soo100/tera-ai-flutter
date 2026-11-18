import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/data/schedule_notification_sync.dart';
import 'package:vivanaut/shared/services/fan_timer_notification_service.dart';

const _device = '4da7f48b-0000-4000-8000-111111111111';
const _gone = '4da7f48b-0000-4000-8000-999999999999';

/// 팬 타이머 알림은 `fan:<기기>`를 싣고(탭하면 그 사육장 홈), 예약 알림 정리
/// (`sched:` 접두)는 팬 알림을 건드리지 않는다(2026-11-16).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late List<Map<String, Object?>> pending;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    pending = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'pendingNotificationRequests' => pending,
        'canScheduleExactNotifications' => false,
        _ => null,
      };
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<Object?> scheduledPayloads() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => (c.arguments as Map<Object?, Object?>)['payload'])
      .toList();
  List<Object?> cancelledIds() => calls
      .where((c) => c.method == 'cancel')
      .map((c) => (c.arguments as Map<Object?, Object?>)['id'])
      .toList();

  test('fan timer started from this phone carries fan:<device>', () async {
    await FanTimerNotificationService()
        .onFanCommandSent(_device, 'fan_on', 30 * 60000);
    expect(scheduledPayloads(), ['fan:$_device']);
  });

  test('fan timer resync (another phone started it) carries fan:<device>',
      () async {
    await FanTimerNotificationService().resyncTimer(_device,
        endsAt: DateTime.now().add(const Duration(minutes: 10)), minutes: 10);
    expect(scheduledPayloads(), ['fan:$_device']);
  });

  test('schedule prune removes only sched: alarms of devices no longer mine',
      () async {
    pending = [
      {'id': 1, 'title': 't', 'body': 'b', 'payload': 'fan:$_gone'},
      {'id': 2, 'title': 't', 'body': 'b', 'payload': 'sched:$_gone'},
      {'id': 3, 'title': 't', 'body': 'b', 'payload': 'sched:$_device'},
      {'id': 4, 'title': 't', 'body': 'b', 'payload': ''},
    ];
    await ScheduleNotificationSync().pruneExcept({_device});
    expect(cancelledIds(), [2]);
  });

  test('schedule re-sync of a device leaves its fan alarm alone', () async {
    pending = [
      {'id': 1, 'title': 't', 'body': 'b', 'payload': 'fan:$_device'},
      {'id': 2, 'title': 't', 'body': 'b', 'payload': 'sched:$_device'},
    ];
    await ScheduleNotificationSync().sync(_device, const []);
    expect(cancelledIds(), [2]);
  });
}
