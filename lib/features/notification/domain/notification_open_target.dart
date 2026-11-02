import 'app_notification.dart';

/// 알림을 열 때 그 알림이 가리키는 사육장으로 홈 세트를 옮긴다(2026-11-02 —
/// 온습도 이탈 푸시는 다른 사육장 것일 수 있어, 그대로 열면 카드 없는 온습도
/// 상세가 뜬다). 푸시 탭과 알림함 탭이 같이 쓴다.
///
/// 그 기기가 [myDeviceIds]에 없거나 목록을 못 읽으면(오류·[timeout] 초과) 선택을
/// 바꾸지 않는다 — 이동은 호출한 쪽이 그대로 한다.
Future<void> selectNotificationDevice(
  AppNotification item, {
  required Future<Iterable<String>> Function() myDeviceIds,
  required void Function(String deviceId) select,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final target = item.targetDeviceId;
  if (target == null) return;
  final Iterable<String> ids;
  try {
    ids = await myDeviceIds().timeout(timeout);
  } catch (_) {
    return;
  }
  if (ids.contains(target)) select(target);
}
