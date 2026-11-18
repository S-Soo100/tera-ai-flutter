/// 알림을 열 때 그 알림이 가리키는 사육장으로 홈 세트를 옮긴다(2026-11-02 —
/// 온습도 이탈 푸시는 다른 사육장 것일 수 있어, 그대로 열면 카드 없는 온습도
/// 상세가 뜬다). 푸시 탭·알림함 탭·로컬 알림(예약·팬 타이머) 탭이 같이 쓴다.
///
/// [deviceId]가 null이거나 [myDeviceIds]에 없거나 목록을 못 읽으면(오류·
/// [timeout] 초과) 선택을 바꾸지 않고 false. 선택했으면 true — 예약 알림은
/// false면 예약 화면 대신 홈으로 간다. 이동은 호출한 쪽이 한다.
Future<bool> selectNotificationDevice(
  String? deviceId, {
  required Future<Iterable<String>> Function() myDeviceIds,
  required void Function(String deviceId) select,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (deviceId == null) return false;
  final Iterable<String> ids;
  try {
    ids = await myDeviceIds().timeout(timeout);
  } catch (_) {
    return false;
  }
  if (!ids.contains(deviceId)) return false;
  select(deviceId);
  return true;
}
