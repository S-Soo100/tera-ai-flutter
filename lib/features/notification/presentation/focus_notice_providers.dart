import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

/// 카메라 렌즈 초점 안내(2026-11-10, 계획 `docs/superpowers/plans/2026-11-10-camera-focus-notice.md`).
///
/// 운영자가 넣은 `camera.focus_needed` 미읽음 행이 있으면 라이브 위 스낵바를
/// 띄운다. 홈은 앱을 켤 때마다 보는 화면이라 알림 전체 stream
/// ([notificationsProvider])을 열지 않고 이 종류만 거른 좁은 stream을 쓴다.

/// 현재 계정의 읽지 않은 초점 안내 id.
final focusNoticeIdsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(notificationRepositoryProvider)
      .watchUnreadOfKind(userId, cameraFocusNotificationKind)
      .map((items) {
    final ids = List<String>.unmodifiable(items.map((item) => item.id));
    debugPrint('[focus-notice] ids=$ids');
    return ids;
  });
});

/// 누른 뒤 서버 갱신이 오기 전까지 바로 숨겨 둘 id. 계정이 바뀌면 비운다.
final focusNoticeDismissedProvider = StateProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return const {};
});

/// 라이브 위 초점 안내 스낵바를 그릴지. 로딩·에러면 그리지 않는다.
final focusNoticeVisibleProvider = Provider.autoDispose<bool>((ref) {
  final ids = ref.watch(focusNoticeIdsProvider).valueOrNull ?? const [];
  final dismissed = ref.watch(focusNoticeDismissedProvider);
  return ids.any((id) => !dismissed.contains(id));
});

/// 지금 보이는 초점 안내를 전부 읽음 처리한다. 먼저 숨기고, 읽음 저장에
/// 실패한 id는 숨김을 풀어 다시 보이게 한다(알림함 미읽음과 어긋나지 않게).
Future<void> dismissFocusNotices(WidgetRef ref) async {
  final ids = ref.read(focusNoticeIdsProvider).valueOrNull ?? const [];
  if (ids.isEmpty) return;
  final dismissed = ref.read(focusNoticeDismissedProvider.notifier);
  dismissed.state = {...dismissed.state, ...ids};
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
