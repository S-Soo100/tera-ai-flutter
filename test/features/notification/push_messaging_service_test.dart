import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'non-Android platforms do not initialize Firebase or request permissions',
      () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [
      TargetPlatform.iOS,
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
}
