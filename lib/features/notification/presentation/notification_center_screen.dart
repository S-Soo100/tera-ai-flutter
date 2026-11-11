import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_page_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/home_set_providers.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../domain/app_notification.dart';
import '../domain/focus_notice_target.dart';
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

  /// 연 뒤, 온습도 이탈이면 그 사육장으로 홈 세트를 옮긴다(푸시 탭과 같은 규칙,
  /// `selectNotificationDevice`). 기기 목록 조회를 기다리지 않고 먼저 이동한다 —
  /// 온습도 상세는 홈 세트를 지켜보므로 옮겨지는 순간 그 사육장으로 바뀐다.
  /// 내 기기 목록에 없는 기기면 이동만 한다.
  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification item,
      String? userId) async {
    if (item.kind == cameraFocusNotificationKind) {
      return _openFocusNotice(context, ref, item, userId);
    }
    if (item.safeRoute == '/notifications') return;
    if (!context.mounted || ref.read(currentUserProvider)?.id != userId) return;
    context.push(item.safeRoute);
    unawaited(selectNotificationDevice(item,
        myDeviceIds: () async => (await ref.read(homeDeviceSetsProvider.future))
            .map((set) => set.device?.id)
            .whereType<String>(),
        select: (id) {
          if (!context.mounted ||
              ref.read(currentUserProvider)?.id != userId) {
            return;
          }
          ref.read(selectedHomeDeviceIdProvider.notifier).state = id;
        }));
  }

  /// 카메라 렌즈 초점 안내 — 안내가 가리키는 카메라(기획 2026-11-11 카메라 단위)
  /// 상세로 가고, 그 카메라의 남은 미읽음 안내도 함께 읽음 처리해 그 카메라 라이브
  /// 막대가 한 번에 사라지게 한다(운영자가 두 번 보낸 경우). 다른 카메라 안내는
  /// 그대로. 카메라가 내 목록에 없으면 카메라 탭으로 `go`.
  Future<void> _openFocusNotice(BuildContext context, WidgetRef ref,
      AppNotification item, String? userId) async {
    final repo = ref.read(notificationRepositoryProvider);
    final target = item.focusCameraId;
    final others = (ref.read(notificationsProvider).valueOrNull ?? const [])
        .where((n) =>
            n.kind == cameraFocusNotificationKind &&
            !n.isRead &&
            n.id != item.id &&
            n.focusCameraId == target)
        .map((n) => n.id);
    unawaited(Future.wait(others.map((id) => repo.markRead(id).catchError(
        (Object e) => debugPrint('[focus-notice] markRead failed id=$id $e')))));
    // 이미 받은 카메라 목록이 있으면 기다리지 않는다. 목록을 못 받으면(오류·
    // 5초 초과) 안내가 가리키는 카메라(v1 행은 카메라 탭에서 고른 카메라)를 믿고
    // 그 상세로 간다 — 일시 오류로 카메라 탭으로 보내지 않게.
    final selected = ref.read(selectedCrecamCameraProvider);
    List<String> ids;
    try {
      final cameras = ref.read(camerasProvider).valueOrNull ??
          await ref
              .read(camerasProvider.future)
              .timeout(const Duration(seconds: 5));
      ids = cameras.map((c) => c.id).toList();
    } catch (_) {
      final fallback = target ?? selected;
      ids = [if (fallback != null) fallback];
    }
    if (!context.mounted || ref.read(currentUserProvider)?.id != userId) return;
    final path = focusNoticeCameraPath(
        myCameraIds: ids, selectedCameraId: selected, targetCameraId: target);
    if (path == null) {
      context.go('/crecam');
    } else {
      context.push(path);
    }
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
      'env',
      'camera'
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
