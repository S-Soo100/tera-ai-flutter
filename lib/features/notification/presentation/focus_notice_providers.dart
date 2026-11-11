import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

/// 카메라 렌즈 초점 안내 — **카메라 단위**(기획
/// `docs/superpowers/specs/2026-11-11-camera-focus-notice-per-camera-design.md`).
///
/// 운영자가 넣은 `camera.focus_needed` 미읽음 행 중 `data.camera_id`가 그
/// 카메라인 것이 있으면, 그 카메라 라이브 위에만 막대를 띄운다. 홈은 앱을 켤
/// 때마다 보는 화면이라 알림 전체 stream([notificationsProvider])을 열지 않고 이
/// 종류만 거른 좁은 stream을 쓴다.

/// 현재 계정의 읽지 않은 초점 안내.
final focusNoticesProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(notificationRepositoryProvider)
      .watchUnreadOfKind(userId, cameraFocusNotificationKind)
      .map((items) {
    if (kDebugMode) {
      debugPrint('[focus-notice] ${[
        for (final n in items) '${n.id}@${n.focusCameraId}'
      ]}');
    }
    return items;
  });
});

/// 누른 뒤 서버 갱신이 오기 전까지 바로 숨겨 둘 id. 계정이 바뀌면 비운다.
final focusNoticeDismissedProvider = StateProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return const {};
});

List<String> _idsFor(List<AppNotification> notices, String cameraId) => [
      for (final n in notices)
        if (n.focusCameraId == cameraId) n.id
    ];

/// [cameraId] 카메라 라이브 위 초점 안내 막대를 그릴지. 로딩·에러면 그리지 않는다.
final focusNoticeVisibleProvider =
    Provider.autoDispose.family<bool, String>((ref, cameraId) {
  final notices = ref.watch(focusNoticesProvider).valueOrNull ?? const [];
  final dismissed = ref.watch(focusNoticeDismissedProvider);
  return _idsFor(notices, cameraId).any((id) => !dismissed.contains(id));
});

/// [cameraId] 카메라의 초점 안내를 전부 읽음 처리한다 — 다른 카메라 안내는 그대로.
/// 먼저 숨기고, 읽음 저장에 실패한 id는 숨김을 풀어 다시 보이게 한다(알림함
/// 미읽음과 어긋나지 않게).
Future<void> dismissFocusNotices(WidgetRef ref, String cameraId) async {
  final notices = ref.read(focusNoticesProvider).valueOrNull ?? const [];
  final ids = _idsFor(notices, cameraId);
  if (ids.isEmpty) return;
  final unread = {for (final n in notices) n.id};
  final dismissed = ref.read(focusNoticeDismissedProvider.notifier);
  // 이미 읽음이 돼 목록에서 빠진 지난 id는 버리고, 이 카메라 id를 더한다.
  dismissed.state = {...dismissed.state.where(unread.contains), ...ids};
  final repo = ref.read(notificationRepositoryProvider);
  await Future.wait(ids.map((id) async {
    try {
      await repo.markRead(id);
    } catch (e) {
      debugPrint('[focus-notice] markRead failed id=$id $e');
      // 그사이 계정이 바뀌었으면 notifier가 새것이다 — 옛 계정 숨김은 이미 비었다.
      if (!dismissed.mounted) return;
      dismissed.state = {...dismissed.state}..remove(id);
    }
  }));
}
