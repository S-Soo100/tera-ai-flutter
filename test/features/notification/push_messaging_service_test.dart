import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'without a Firebase app (iOS before GoogleService-Info.plist) and on '
      'desktop, push stays off and never asks for permission', () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [
      // iOS도 초기화는 시도한다 — 설정 파일이 없으면 예외로 끝나 앱이 없다.
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await PushMessagingService.initialize();
      final service = PushMessagingService();
      expect(service.supported, isFalse);
      expect(await service.getPermission(), PushPermission.unavailable);
      expect(await service.requestPermission(), PushPermission.unavailable);
      expect(await service.getToken(), isNull);
      await service.deleteToken();
      expect(await service.getInitialMessage(), isNull);
      expect(await service.onMessage.toList(), isEmpty);
    }
  });
  test('payload reads only string routing fields and notification presentation',
      () {
    final message = PushMessage.fromRemote(const RemoteMessage(
      messageId: 'm1',
      data: {'notification_id': 'n1', 'kind': 42, 'route': []},
      notification: RemoteNotification(title: '제목', body: '본문'),
    ));
    expect(message.messageId, 'm1');
    expect(message.notificationId, 'n1');
    expect(message.kind, '');
    expect(message.route, '');
    expect(message.title, '제목');
    expect(message.body, '본문');
  });

  group('fetchPushToken', () {
    late List<String> calls;
    late List<Duration> waits;
    Future<void> wait(Duration d) async => waits.add(d);
    setUp(() {
      calls = [];
      waits = [];
    });

    test('Android asks FCM directly', () async {
      final token = await fetchPushToken(
          needsApns: false,
          apnsToken: () async {
            calls.add('apns');
            return null;
          },
          fcmToken: () async {
            calls.add('fcm');
            return 'fcm-token';
          },
          wait: wait);
      expect(token, 'fcm-token');
      expect(calls, ['fcm']);
    });

    test('iOS waits for the APNs token, retrying a few times', () async {
      final apns = <String?>[null, null, 'apns-token'];
      final token = await fetchPushToken(
          needsApns: true,
          apnsToken: () async {
            calls.add('apns');
            return apns.removeAt(0);
          },
          fcmToken: () async {
            calls.add('fcm');
            return 'fcm-token';
          },
          retryDelay: const Duration(milliseconds: 300),
          wait: wait);
      expect(token, 'fcm-token');
      expect(calls, ['apns', 'apns', 'apns', 'fcm']);
      expect(waits, const [
        Duration(milliseconds: 300),
        Duration(milliseconds: 300)
      ]);
    });

    test('iOS gives up after 3 tries without asking FCM (next sync retries)',
        () async {
      final token = await fetchPushToken(
          needsApns: true,
          apnsToken: () async {
            calls.add('apns');
            return null;
          },
          fcmToken: () async {
            calls.add('fcm');
            return 'fcm-token';
          },
          wait: wait);
      expect(token, isNull);
      expect(calls, ['apns', 'apns', 'apns']);
      expect(waits, hasLength(2));
    });

    test('an empty APNs token counts as missing', () async {
      final token = await fetchPushToken(
          needsApns: true,
          apnsToken: () async => '',
          fcmToken: () async => 'fcm-token',
          wait: wait);
      expect(token, isNull);
    });
  });
}
