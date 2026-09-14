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

/// Background notification payloads are displayed by Android, never twice here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushMessagingService implements PushMessagingPort {
  @override
  bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Firebase.apps.isNotEmpty;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
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
  Future<String?> getToken() async =>
      supported ? await _messaging.getToken() : null;
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
