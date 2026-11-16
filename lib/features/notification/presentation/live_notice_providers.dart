import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

/// 라이브 위 카메라 단위 안내 막대 — 렌즈 초점(`camera.focus_needed`, 기획
/// `docs/superpowers/specs/2026-11-11-camera-focus-notice-per-camera-design.md`)과
/// 네트워크 신호 약함(`camera.weak_signal`, 기획
/// `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`).
///
/// 종류마다 안 읽은 행 중 그 카메라를 가리키는 것(`data.camera_id`/`device_id`
/// — uuid든 기기 ID든)이 있으면, 그 카메라 라이브 위에만 막대를 띄운다. 막대는
/// 하나만 — [liveNoticeKinds] 순서로 먼저 걸린 종류를 그린다. 홈은 앱을 켤
/// 때마다 보는 화면이라 알림 전체 stream([notificationsProvider])을 열지 않고
/// 종류만 거른 좁은 stream을 쓴다. 서버가 `read_at`을 채우면(신호 회복) 그 행이
/// stream에서 빠져 막대가 저절로 내려간다.

/// 막대를 그릴 카메라 — `cameras.id`와 기기 ID(`cameras.camera_id`).
typedef LiveNoticeCamera = ({String id, String deviceId});

/// 현재 계정의 읽지 않은 [kind] 안내.
final liveNoticesProvider = StreamProvider.autoDispose
    .family<List<AppNotification>, String>((ref, kind) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(notificationRepositoryProvider)
      .watchUnreadOfKind(userId, kind)
      .map((items) {
    if (kDebugMode) {
      debugPrint('[live-notice] $kind ${[
        for (final n in items) '${n.id}@${n.liveCameraRefs.join('|')}'
      ]}');
    }
    return items;
  });
});

/// 카메라 표시(uuid·기기 ID) → 그것을 가리키는 [kind] 미읽음 안내 id. 목록이
/// 바뀔 때 한 번만 묶고, 카메라별 막대는 여기서 찾아 쓴다.
final liveNoticeIdsByRefProvider = Provider.autoDispose
    .family<Map<String, List<String>>, String>((ref, kind) {
  final notices = ref.watch(liveNoticesProvider(kind)).valueOrNull ?? const [];
  final byRef = <String, List<String>>{};
  for (final n in notices) {
    for (final r in n.liveCameraRefs) {
      (byRef[r] ??= []).add(n.id);
    }
  }
  return byRef;
});

/// 누른 뒤 서버 갱신이 오기 전까지 바로 숨겨 둘 id(종류 공용 — id는 행마다
/// 다르다). 계정이 바뀌면 비운다.
final liveNoticeDismissedProvider = StateProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return const {};
});

Set<String> _idsFor(Map<String, List<String>> byRef, LiveNoticeCamera camera) =>
    {
      ...?byRef[camera.id],
      ...?byRef[camera.deviceId],
    };

/// [camera] 라이브 위에 그릴 안내 종류 — 없으면 null. 로딩·에러면 그리지 않는다.
final liveNoticeKindProvider =
    Provider.autoDispose.family<String?, LiveNoticeCamera>((ref, camera) {
  final dismissed = ref.watch(liveNoticeDismissedProvider);
  for (final kind in liveNoticeKinds) {
    final ids = _idsFor(ref.watch(liveNoticeIdsByRefProvider(kind)), camera);
    if (ids.any((id) => !dismissed.contains(id))) return kind;
  }
  return null;
});

/// [camera]의 [kind] 안내를 전부 읽음 처리한다 — 다른 카메라·다른 종류 안내는
/// 그대로. 먼저 숨기고, 읽음 저장에 실패한 id는 숨김을 풀어 다시 보이게 한다
/// (알림함 미읽음과 어긋나지 않게).
Future<void> dismissLiveNotices(
    WidgetRef ref, LiveNoticeCamera camera, String kind) async {
  final ids = _idsFor(ref.read(liveNoticeIdsByRefProvider(kind)), camera);
  if (ids.isEmpty) return;
  final unread = {
    for (final k in liveNoticeKinds)
      for (final n in ref.read(liveNoticesProvider(k)).valueOrNull ?? const [])
        n.id
  };
  final dismissed = ref.read(liveNoticeDismissedProvider.notifier);
  // 이미 읽음이 돼 목록에서 빠진 지난 id는 버리고, 이 카메라 id를 더한다.
  dismissed.state = {...dismissed.state.where(unread.contains), ...ids};
  final repo = ref.read(notificationRepositoryProvider);
  await Future.wait(ids.map((id) async {
    try {
      await repo.markRead(id);
    } catch (e) {
      debugPrint('[live-notice] markRead failed id=$id $e');
      // 그사이 계정이 바뀌었으면 notifier가 새것이다 — 옛 계정 숨김은 이미 비었다.
      if (!dismissed.mounted) return;
      dismissed.state = {...dismissed.state}..remove(id);
    }
  }));
}
