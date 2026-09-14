import 'dart:async';
import '../data/push_device_repository.dart';
import '../data/push_messaging_service.dart';
import '../data/push_preferences.dart';
import 'app_notification.dart';
import 'notification_route.dart';

/// Serializes registration and logout; stale async completions cannot re-enable
/// a signed-out installation or show another account's notification.
class PushLifecycleController {
  PushLifecycleController(
      {required this.messaging,
      required this.devices,
      required this.preferences,
      required this.appVersion,
      required this.locale,
      required this.findNotification,
      required this.markRead,
      required this.display,
      required this.navigate,
      required this.permissionChanged,
      required this.reportError});

  final PushMessagingPort messaging;
  final PushDevicePort devices;
  final PushPreferences preferences;
  final Future<String> Function() appVersion;
  final String Function() locale;
  final Future<AppNotification?> Function(String, String) findNotification;
  final Future<void> Function(String) markRead;
  final Future<void> Function(PushMessage) display;
  final void Function(String) navigate;
  final void Function(PushPermission) permissionChanged;
  final void Function(String) reportError;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _displayed = <String>{};
  final _opened = <String>{};
  Future<void> _registrations = Future.value();
  String? _userId;
  int _generation = 0;
  bool _disposed = false;
  bool _started = false;
  bool _loggingOut = false;
  bool _logoutInProgress = false;
  PushMessage? _pendingTap;

  Future<void> start() async {
    if (_started || _disposed || !messaging.supported) return;
    _started = true;
    _subscriptions.addAll([
      messaging.onTokenRefresh.listen(
          (token) => unawaited(synchronize(token: token)),
          onError: (Object _) => reportError('token_stream')),
      messaging.onMessage.listen(
          (message) =>
              unawaited(_guard(() => foreground(message), 'foreground')),
          onError: (Object _) => reportError('message_stream')),
      messaging.onMessageOpenedApp.listen(
          (message) => unawaited(_guard(() => open(message), 'tap')),
          onError: (Object _) => reportError('tap_stream')),
    ]);
    await _guard(() async {
      final initial = await messaging.getInitialMessage();
      if (initial != null) await open(initial);
    }, 'initial_message');
  }

  Future<void> setUser(String? userId) async {
    if (_disposed) return;
    if (_userId != userId) {
      _generation++;
      _displayed.clear();
      _opened.clear();
      _userId = userId;
      if (userId != null && !_logoutInProgress) _loggingOut = false;
    }
    await synchronize();
    final pending = _pendingTap;
    if (pending != null && _userId != null) {
      _pendingTap = null;
      await _guard(() => open(pending), 'pending_tap');
    }
  }

  bool _current(String userId, int generation) =>
      !_disposed &&
      !_loggingOut &&
      _userId == userId &&
      _generation == generation;

  Future<void> synchronize({String? token}) {
    final userId = _userId;
    final generation = _generation;
    if (userId == null ||
        !_current(userId, generation) ||
        !messaging.supported) {
      return Future.value();
    }
    return _registrations = _registrations.then((_) => _guard(() async {
          if (!_current(userId, generation)) return;
          final permission = await messaging.getPermission();
          if (!_current(userId, generation)) return;
          permissionChanged(permission);
          if (permission != PushPermission.authorized) return;
          final currentToken = token ?? await messaging.getToken();
          if (!_current(userId, generation) ||
              currentToken == null ||
              currentToken.isEmpty) {
            return;
          }
          final installation = await preferences.installationId();
          final version = await appVersion();
          if (!_current(userId, generation)) return;
          await devices.register(
              userId: userId,
              installationId: installation,
              token: currentToken,
              appVersion: version,
              locale: locale());
        }, 'registration'));
  }

  Future<void> requestPermission({bool retry = false}) async {
    if (_userId == null || _loggingOut || !messaging.supported) return;
    await _guard(() async {
      final permission = await messaging.requestPermission();
      if (_disposed) return;
      permissionChanged(permission);
      if (permission == PushPermission.authorized) {
        await synchronize();
      } else if (retry && permission == PushPermission.denied) {
        await messaging.openSettings();
      }
    }, 'permission');
  }

  Future<void> logout(Future<void> Function() signOut) async {
    _logoutInProgress = true;
    _loggingOut = true;
    _generation++;
    _pendingTap = null;
    try {
      await _registrations;
      await _guard(() async {
        if (messaging.supported) {
          await devices.deactivate(await preferences.installationId());
        }
      }, 'deactivation');
      await signOut();
      _userId = null;
    } catch (_) {
      // Failed signout leaves the session authenticated; allow a later retry.
      _loggingOut = false;
      rethrow;
    } finally {
      _logoutInProgress = false;
    }
  }

  Future<void> foreground(PushMessage message) async {
    final userId = _userId;
    final generation = _generation;
    if (userId == null ||
        !_current(userId, generation) ||
        message.notificationId.isEmpty) {
      return;
    }
    final key = message.notificationId;
    if (!_displayed.add(key)) return;
    var delivered = false;
    try {
      final item = await findNotification(message.notificationId, userId);
      if (item == null ||
          item.userId != userId ||
          !_current(userId, generation)) {
        return;
      }
      if (await messaging.getPermission() != PushPermission.authorized ||
          !_current(userId, generation)) {
        return;
      }
      await display(PushMessage(
          messageId: message.messageId,
          notificationId: item.id,
          kind: item.kind,
          route: item.safeRoute,
          title: item.title,
          body: item.body));
      delivered = true;
      _bound(_displayed);
    } finally {
      if (!delivered && generation == _generation) _displayed.remove(key);
    }
  }

  Future<void> open(PushMessage message) async {
    if (_disposed || _loggingOut || message.notificationId.isEmpty) return;
    final userId = _userId;
    if (userId == null) {
      _pendingTap = message;
      return;
    }
    final generation = _generation;
    if (!_opened.add(message.notificationId)) return;
    var opened = false;
    try {
      final item = await findNotification(message.notificationId, userId);
      if (item == null ||
          item.userId != userId ||
          !_current(userId, generation)) {
        return;
      }
      await markRead(item.id);
      if (!_current(userId, generation)) return;
      // Both the payload and the current DB record must permit this destination.
      final route = knownNotificationKinds.contains(message.kind)
          ? sanitizeNotificationRoute(message.route)
          : '/notifications';
      navigate(route == item.safeRoute ? route : '/notifications');
      opened = true;
      _bound(_opened);
    } finally {
      if (!opened && generation == _generation) {
        _opened.remove(message.notificationId);
      }
    }
  }

  void _bound(Set<String> ids) {
    if (ids.length > 128) ids.remove(ids.first);
  }

  Future<void> _guard(Future<void> Function() action, String code) async {
    try {
      await action();
    } catch (_) {
      if (!_disposed) reportError(code);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
