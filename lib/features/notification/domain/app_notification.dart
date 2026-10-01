import 'package:easy_localization/easy_localization.dart';

import 'notification_route.dart';

const knownNotificationKinds = {
  'highlight.ready',
  'device.action.started',
  'device.action.ended',
  'device.action.failed',
  'device.action.skipped',
  'community.comment',
  'community.like_digest',
  'notice.published',
  'maintenance.water_tank',
  'safety.alert',
  'safety.recovered',
};

class AppNotification {
  AppNotification.fromJson(Map<String, Object?> json)
      : id = _string(json['id']),
        userId = _string(json['user_id']),
        kind = _string(json['kind']),
        category = knownNotificationKinds.contains(json['kind'])
            ? _string(json['category'])
            : 'other',
        title = _string(json['title']),
        body = _string(json['body']),
        route = _string(json['route']),
        data = _data(json['data']),
        createdAt = _date(json['created_at']),
        readAt = _date(json['read_at']);

  final String id;
  final String userId;
  final String kind;
  final String category;
  final String title;
  final String body;
  final String route;
  final Map<String, Object?> data;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// 예약 시각에 기기가 오프라인이라 서버가 명령 없이 실패 처리한 알림
  /// (terra-server#16, 2026-10-01). 서버 문구는 일반 "실행 실패"라 앱이 바꾼다.
  bool get isScheduleDeviceOffline =>
      kind == 'device.action.failed' && _field('result') == 'device_offline';

  /// 화면에 그릴 제목·본문 — 앱이 문구를 정하는 알림만 바꾸고 나머지는 서버 값.
  /// 앱 밖(백그라운드) 푸시는 OS가 서버 문구로 그려 여기를 거치지 않는다.
  String get displayTitle {
    if (!isScheduleDeviceOffline) return title;
    final name = _field('device_name');
    return name == null
        ? 'schedule_offline_title'.tr()
        : 'schedule_offline_title_named'.tr(args: [name]);
  }

  String get displayBody {
    if (!isScheduleDeviceOffline) return body;
    final action = _field('action');
    final key = 'routine_action_$action';
    final label = action == null ? null : key.tr();
    return label == null || label == key
        ? 'schedule_offline_body'.tr()
        : 'schedule_offline_body_action'.tr(args: [label]);
  }

  /// `data` 바로 아래 또는 `data.payload` 아래의 비어 있지 않은 문자열.
  String? _field(String name) {
    final payload = data['payload'];
    final v =
        data[name] ?? (payload is Map<String, Object?> ? payload[name] : null);
    return v is String && v.isNotEmpty ? v : null;
  }

  String get safeRoute => knownNotificationKinds.contains(kind)
      ? sanitizeNotificationRoute(route)
      : '/notifications';

  static String _string(Object? value) => value is String ? value : '';
  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static Map<String, Object?> _data(Object? value) => value
          is Map<String, Object?>
      ? Map.unmodifiable(value.map((key, item) => MapEntry(key, _freeze(item))))
      : const {};
  static Object? _freeze(Object? value) => switch (value) {
        Map<String, Object?> map => _data(map),
        List<Object?> list => List<Object?>.unmodifiable(list.map(_freeze)),
        _ => value,
      };
}
