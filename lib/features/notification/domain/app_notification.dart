import 'notification_route.dart';

const knownNotificationKinds = {
  'highlight.ready',
  'device.action.started',
  'device.action.ended',
  'device.action.failed',
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
