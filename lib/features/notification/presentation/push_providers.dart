import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../shared/services/local_notifications.dart';
import '../../profile/presentation/profile_providers.dart';
import '../data/push_device_repository.dart';
import '../data/push_messaging_service.dart';
import '../data/push_preferences.dart';
import '../domain/push_lifecycle_controller.dart';
import 'notification_providers.dart';

final pushMessagingProvider =
    Provider<PushMessagingPort>((ref) => PushMessagingService());
final pushPreferencesProvider =
    Provider<PushPreferences>((ref) => HivePushPreferences());
final pushPermissionProvider =
    StateProvider<PushPermission>((ref) => PushPermission.unavailable);
final pushPermissionBusyProvider = StateProvider<bool>((ref) => false);
final pushDevicesProvider = Provider<PushDevicePort>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PushDeviceRepository(
      currentUserId: () => client.auth.currentUser?.id,
      rpc: (name, params) async {
        await client.rpc(name, params: params);
      });
});

final pushLifecycleControllerProvider =
    Provider<PushLifecycleController>((ref) {
  final notifications = ref.watch(notificationRepositoryProvider);
  final core = LocalNotifications.instance;
  final controller = PushLifecycleController(
    messaging: ref.watch(pushMessagingProvider),
    devices: ref.watch(pushDevicesProvider),
    preferences: ref.watch(pushPreferencesProvider),
    appVersion: () => ref.read(appVersionProvider.future),
    locale: () => 'ko',
    findNotification: (id, userId) =>
        notifications.findById(id, userId).timeout(const Duration(seconds: 10)),
    markRead: notifications.markRead,
    display: (message) => core.showRemote(
      // Negative IDs never cancel/replace the existing positive fan timer IDs.
      id: -1 - (message.notificationId.hashCode & 0x3fffffff),
      title: message.title, body: message.body,
      safety: message.kind.startsWith('safety.'),
      payload: jsonEncode({
        'notification_id': message.notificationId,
        'kind': message.kind,
        'route': message.route
      }),
    ),
    navigate: (route) {
      final router = ref.read(routerProvider);
      if (router.routeInformationProvider.value.uri.path != route) {
        unawaited(router.push<void>(route));
      }
    },
    permissionChanged: (permission) =>
        ref.read(pushPermissionProvider.notifier).state = permission,
    reportError: (code) => debugPrint('[push] $code failed'),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

Future<void> requestPushPermission(WidgetRef ref, {bool retry = false}) async {
  if (ref.read(pushPermissionBusyProvider)) return;
  final busy = ref.read(pushPermissionBusyProvider.notifier);
  final controller = ref.read(pushLifecycleControllerProvider);
  busy.state = true;
  try {
    await controller.requestPermission(retry: retry);
  } finally {
    busy.state = false;
  }
}
