import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_page_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/home_set_providers.dart';
import '../domain/app_notification.dart';
import '../domain/notification_open_target.dart';
import 'notification_providers.dart';
import 'push_permission_prompt.dart';

final _notificationActionsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => {});

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final busy = ref.watch(_notificationActionsProvider);
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    void retry() {
      if (userId != null) ref.invalidate(userNotificationsProvider(userId));
    }

    return GlassPageShell(
      child: Scaffold(
        appBar: AppBar(title: Text('home_notifications'.tr()), actions: [
          TextButton(
              onPressed: unread == 0 || busy.contains('all') || userId == null
                  ? null
                  : () => _action(context, ref, 'all', () async {
                        await ref
                            .read(notificationRepositoryProvider)
                            .markAllRead(userId);
                      }),
              child: Text('notifications_mark_all'.tr())),
        ]),
        body: Column(children: [
          const PushPermissionBanner(),
          if (items.hasError && items.hasValue) _RetryNotice(onRetry: retry),
          Expanded(
              child: items.when(
            skipLoadingOnRefresh: true,
            skipError: items.hasValue,
            loading: () => const SkeletonPageLoading(cardCount: 4),
            error: (_, __) => Center(child: _RetryNotice(onRetry: retry)),
            data: (notifications) => notifications.isEmpty
                ? Center(child: Text('notifications_empty'.tr()))
                : RefreshIndicator(
                    onRefresh: () async {
                      if (userId != null) {
                        ref.invalidate(userNotificationsProvider(userId));
                        try {
                          await ref
                              .read(userNotificationsProvider(userId).future);
                        } catch (_) {/* Stream error is rendered above. */}
                      }
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final colors = Theme.of(context).colorScheme;
                        return ListTile(
                          key: ValueKey('notification_${item.id}'),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          tileColor:
                              item.isRead ? null : colors.surfaceContainerLow,
                          leading: item.isRead
                              ? const Icon(Icons.notifications_none)
                              : Icon(Icons.circle,
                                  size: 10,
                                  color: colors.error,
                                  key: ValueKey(
                                      'notification_unread_${item.id}')),
                          title: Text(item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontWeight: item.isRead
                                          ? FontWeight.normal
                                          : FontWeight.w700)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.body),
                                const SizedBox(height: 6),
                                Text(
                                    '${_category(item.category)} · ${_time(item.createdAt)}',
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                              ]),
                          onTap: busy.contains(item.id)
                              ? null
                              : () => _action(context, ref, item.id, () async {
                                    await ref
                                        .read(notificationRepositoryProvider)
                                        .markRead(item.id);
                                    if (!context.mounted ||
                                        ref.read(currentUserProvider)?.id !=
                                            userId) {
                                      return;
                                    }
                                    await _open(context, ref, item, userId);
                                  }),
                        );
                      },
                    )),
          )),
        ]),
      ),
    );
  }

  /// 온습도 이탈이면 그 사육장으로 홈 세트를 옮긴 뒤 연다(푸시 탭과 같은 규칙,
  /// `selectNotificationDevice`). 내 기기 목록에 없는 기기면 이동만 한다.
  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification item,
      String? userId) async {
    if (item.safeRoute == '/notifications') return;
    await selectNotificationDevice(item,
        myDeviceIds: () async => (await ref.read(homeDeviceSetsProvider.future))
            .map((set) => set.device?.id)
            .whereType<String>(),
        select: (id) {
          if (!context.mounted) return;
          ref.read(selectedHomeDeviceIdProvider.notifier).state = id;
        });
    if (!context.mounted || ref.read(currentUserProvider)?.id != userId) return;
    context.push(item.safeRoute);
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String key,
      Future<void> Function() action) async {
    final busy = ref.read(_notificationActionsProvider.notifier);
    busy.state = {...busy.state, key};
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('notifications_read_error'.tr())));
      }
    } finally {
      if (context.mounted) busy.state = {...busy.state}..remove(key);
    }
  }

  String _category(String category) {
    const categories = {
      'highlight',
      'device',
      'community',
      'notice',
      'maintenance',
      'safety',
      'env'
    };
    return 'notifications_category_${categories.contains(category) ? category : 'other'}'
        .tr();
  }

  String _time(DateTime? time) {
    if (time == null) return 'notifications_time_unknown'.tr();
    final elapsed = DateTime.now().difference(time);
    if (!elapsed.isNegative && elapsed.inMinutes < 1) {
      return 'notifications_just_now'.tr();
    }
    if (!elapsed.isNegative && elapsed.inMinutes < 60) {
      return 'notifications_minutes_ago'.tr(args: ['${elapsed.inMinutes}']);
    }
    if (!elapsed.isNegative && elapsed.inHours < 24) {
      return 'notifications_hours_ago'.tr(args: ['${elapsed.inHours}']);
    }
    return DateFormat('notifications_date_format'.tr(), 'ko')
        .format(time.toLocal());
  }
}

class _RetryNotice extends StatelessWidget {
  const _RetryNotice({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('notifications_load_error'.tr()),
        TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
      ]);
}
