import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationRepository(SupabaseNotificationStore(client),
      currentUserId: () => client.auth.currentUser?.id);
});

final userNotificationsProvider = StreamProvider.autoDispose
    .family<List<AppNotification>, String>((ref, userId) =>
        ref.watch(notificationRepositoryProvider).watchNotifications(userId));

/// A new family instance cannot carry the previous account's cached AsyncData.
final notificationsProvider =
    Provider<AsyncValue<List<AppNotification>>>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return const AsyncData([]);
  return ref.watch(userNotificationsProvider(userId));
});

final unreadNotificationCountProvider = Provider<int>((ref) =>
    ref
        .watch(notificationsProvider)
        .valueOrNull
        ?.where((item) => !item.isRead)
        .length ??
    0);
