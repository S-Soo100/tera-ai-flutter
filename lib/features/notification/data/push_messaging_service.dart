import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum PushPermission { unavailable, notDetermined, denied, authorized }

class PushMessage {
  const PushMessage(
      {this.messageId,
      required this.notificationId,
      this.kind = '',
      this.route = '',
      this.title = '',
      this.body = ''});
  final String? messageId;
  final String notificationId;
  final String kind;
  final String route;
  final String title;
  final String body;

  factory PushMessage.fromRemote(RemoteMessage message) => PushMessage(
        messageId: message.messageId,
        notificationId: _string(message.data['notification_id']),
        kind: _string(message.data['kind']),
        route: _string(message.data['route']),
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
      );
  static String _string(Object? value) => value is String ? value : '';
}

abstract interface class PushMessagingPort {
  bool get supported;
  Future<PushPermission> getPermission();
  Future<PushPermission> requestPermission();
  Future<String?> getToken();
  Future<void> deleteToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onMessage;
  Stream<PushMessage> get onMessageOpenedApp;
  Future<PushMessage?> getInitialMessage();
  Future<void> openSettings();
}

/// iOS는 APNs 토큰이 생긴 뒤에야 FCM 토큰을 준다 — 그 전에 `getToken()`을 부르면
/// 실패한다. 앱 시작 직후엔 APNs 등록이 아직 안 끝났을 수 있어 [attempts]번까지
/// [retryDelay] 간격으로 다시 본다. 끝내 없으면 null — 다음 동기화(복귀·토큰
/// 갱신·계정 연결)에서 다시 시도한다. Android는 바로 FCM에 묻는다.
Future<String?> fetchPushToken({
  required bool needsApns,
  required Future<String?> Function() apnsToken,
  required Future<String?> Function() fcmToken,
  int attempts = 3,
  Duration retryDelay = const Duration(milliseconds: 500),
  Future<void> Function(Duration)? wait,
}) async {
  if (needsApns) {
    final pause = wait ?? Future<void>.delayed;
    var ready = false;
    for (var i = 0; i < attempts && !ready; i++) {
      if (i > 0) await pause(retryDelay);
      final token = await apnsToken();
      ready = token != null && token.isNotEmpty;
    }
    if (!ready) return null;
  }
  return fcmToken();
}

/// FCM을 켜는 플랫폼 — Android와 iOS. 둘 다 Firebase 앱이 있어야 실제로 켜진다
/// (iOS는 `GoogleService-Info.plist`가 없으면 초기화가 예외로 끝나 꺼진 채).
bool _pushPlatform() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Background notification payloads are displayed by the OS (Android·iOS),
/// never twice here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushMessagingService implements PushMessagingPort {
  @override
  bool get supported => _pushPlatform() && Firebase.apps.isNotEmpty;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<void> initialize() async {
    if (!_pushPlatform()) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      // No exception payload: vendor errors may contain identifiers or tokens.
      debugPrint('[push] initialization failed; retry on next launch');
    }
  }

  PushPermission _permission(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.authorized,
        AuthorizationStatus.denied => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<PushPermission> getPermission() async => supported
      ? _permission(
          (await _messaging.getNotificationSettings()).authorizationStatus)
      : PushPermission.unavailable;
  @override
  Future<PushPermission> requestPermission() async => supported
      ? _permission((await _messaging.requestPermission()).authorizationStatus)
      : PushPermission.unavailable;
  @override
  Future<String?> getToken() async {
    if (!supported) return null;
    return fetchPushToken(
        needsApns: defaultTargetPlatform == TargetPlatform.iOS,
        apnsToken: _messaging.getAPNSToken,
        fcmToken: _messaging.getToken);
  }
  @override
  Future<void> deleteToken() async {
    if (supported) await _messaging.deleteToken();
  }

  @override
  Stream<String> get onTokenRefresh =>
      supported ? _messaging.onTokenRefresh : const Stream.empty();
  @override
  Stream<PushMessage> get onMessage => supported
      ? FirebaseMessaging.onMessage.map(PushMessage.fromRemote)
      : const Stream.empty();
  @override
  Stream<PushMessage> get onMessageOpenedApp => supported
      ? FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote)
      : const Stream.empty();
  @override
  Future<PushMessage?> getInitialMessage() async {
    if (!supported) return null;
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushMessage.fromRemote(message);
  }

  @override
  Future<void> openSettings() async {
    if (supported) await openAppSettings();
  }
}
