import 'dart:convert';

/// 로컬 알림 payload 읽기(2026-11-16 — 알림 눌러 해당 화면 이동).
///
/// 이 폰이 건 로컬 알림은 세 종류다.
/// - `sched:<기기 uuid>` — 예약 실행 시각 알림(`ScheduleNotificationSync`).
/// - `fan:<기기 uuid>` — 팬 타이머 종료 알림(`FanTimerNotificationService`).
/// - JSON(`notification_id` 포함) — 앱 사용 중 받은 서버 푸시를 다시 띄운 것
///   (`LocalNotifications.showRemote`). 서버 푸시 탭과 같은 경로로 넘긴다.
///
/// payload는 폰 밖에서도 만들 수 있으니 형식이 정확할 때만 받고, 나머지는
/// 무시한다(null).

const kScheduleNotificationPrefix = 'sched:';
const kFanNotificationPrefix = 'fan:';

/// 팬 타이머 알림에 심는 payload — 읽는 쪽([parseLocalNotificationPayload])과
/// 접두를 한 곳에서 맞춘다.
String fanNotificationPayload(String deviceId) =>
    '$kFanNotificationPrefix$deviceId';

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

enum DeviceNotificationKind { schedule, fan }

sealed class LocalNotificationTarget {
  const LocalNotificationTarget();
}

/// 사육장 기기 하나를 가리키는 로컬 알림(예약·팬 타이머).
final class DeviceNotificationTarget extends LocalNotificationTarget {
  const DeviceNotificationTarget(this.kind, this.deviceId);
  final DeviceNotificationKind kind;
  final String deviceId;

  /// 기기 선택을 마친 뒤 갈 곳. 예약은 그 사육장이 홈에서 선택됐을 때만 예약
  /// 화면이다 — 예약 화면은 홈 선택 사육장을 보여 주므로, 선택하지 못했으면
  /// (내 기기 아님·목록 조회 실패) 엉뚱한 사육장 예약을 고치지 않게 홈으로.
  /// 팬 타이머는 언제나 홈.
  String routeAfterSelect({required bool selected}) =>
      kind == DeviceNotificationKind.schedule && selected
          ? '/home/routines'
          : '/home';

  @override
  bool operator ==(Object other) =>
      other is DeviceNotificationTarget &&
      other.kind == kind &&
      other.deviceId == deviceId;
  @override
  int get hashCode => Object.hash(kind, deviceId);
  @override
  String toString() => 'DeviceNotificationTarget($kind, $deviceId)';
}

/// 앱 사용 중 다시 띄운 서버 푸시 — 서버 푸시 탭 경로(`PushLifecycleController.open`)로.
final class PushNotificationTarget extends LocalNotificationTarget {
  const PushNotificationTarget(
      {required this.notificationId, required this.kind, required this.route});
  final String notificationId;
  final String kind;
  final String route;

  @override
  bool operator ==(Object other) =>
      other is PushNotificationTarget &&
      other.notificationId == notificationId &&
      other.kind == kind &&
      other.route == route;
  @override
  int get hashCode => Object.hash(notificationId, kind, route);
  @override
  String toString() => 'PushNotificationTarget($notificationId, $kind, $route)';
}

LocalNotificationTarget? parseLocalNotificationPayload(String payload) {
  final device = _deviceTarget(payload, kScheduleNotificationPrefix,
          DeviceNotificationKind.schedule) ??
      _deviceTarget(payload, kFanNotificationPrefix, DeviceNotificationKind.fan);
  if (device != null) return device;
  if (!payload.startsWith('{')) return null;
  final Object? json;
  try {
    json = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, Object?>) return null;
  final id = json['notification_id'];
  if (id is! String || id.isEmpty) return null;
  final kind = json['kind'];
  final route = json['route'];
  return PushNotificationTarget(
      notificationId: id,
      kind: kind is String ? kind : '',
      route: route is String ? route : '');
}

DeviceNotificationTarget? _deviceTarget(
    String payload, String prefix, DeviceNotificationKind kind) {
  if (!payload.startsWith(prefix)) return null;
  final id = payload.substring(prefix.length);
  return _uuid.hasMatch(id) ? DeviceNotificationTarget(kind, id) : null;
}
