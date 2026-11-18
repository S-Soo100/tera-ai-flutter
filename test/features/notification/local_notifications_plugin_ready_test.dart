import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/services/local_notifications.dart';

/// 앱 시작 때 부르는 플러그인 초기화(탭 콜백용)는 시간대 DB를 읽지 않고,
/// 예약용 초기화에서만 한 번 읽는다(코드 리뷰 2026-11-18 — 시작 비용).
/// 싱글턴 상태가 다른 테스트와 섞이지 않게 파일을 따로 둔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensurePluginReady skips timezone; ensureInitialized loads it once',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const notifications =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const timezone = MethodChannel('flutter_timezone');
    var initializes = 0;
    var timezoneCalls = 0;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize') {
        initializes++;
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(timezone, (call) async {
      timezoneCalls++;
      return 'Asia/Seoul';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(timezone, null);
    });

    final core = LocalNotifications.instance;
    await core.ensurePluginReady();
    await core.deliverInitialTap();
    expect(initializes, 1);
    expect(timezoneCalls, 0, reason: '탭 준비만으로 시간대를 읽지 않는다');

    await Future.wait([core.ensureInitialized(), core.ensureInitialized()]);
    expect(initializes, 1, reason: '플러그인은 다시 초기화하지 않는다');
    expect(timezoneCalls, 1, reason: '예약용 초기화에서 한 번만 읽는다');

    await core.ensureInitialized();
    expect(timezoneCalls, 1);
  });
}
