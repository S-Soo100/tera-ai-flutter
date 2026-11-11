import 'notification_route.dart';

/// v4 온습도 이탈 푸시(terra-server `docs/APP_ENV_ALERT_PUSH_2026-11-02.md` §2).
const envAlertNotificationKind = 'env.alert.triggered';

/// 운영자가 특정 사용자에게 보내는 카메라 렌즈 초점 안내(사람 단위, 푸시 없음).
/// 운영자가 SQL로 app_notifications에 직접 넣는다 — `docs/ops/camera-focus-notice.md`.
const cameraFocusNotificationKind = 'camera.focus_needed';

const knownNotificationKinds = {
  cameraFocusNotificationKind,
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
  envAlertNotificationKind,
};

/// 높은 중요도 채널(`vivanaut_safety`)로 띄울 알림. 서버 발송 채널 규칙과 같다
/// (`supabase/functions/_shared/firebase-message.mjs` `usesSafetyChannel`).
bool usesSafetyChannel(String kind) =>
    kind.startsWith('safety.') || kind == envAlertNotificationKind;

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

  /// 이 알림을 열 때 홈 세트를 옮길 사육장 기기 id. 지금은 온습도 이탈만 —
  /// `data`는 서버 트리거가 payload를 합친 것이라 `device_id`가 들어 있다.
  /// (같이 합쳐진 `data.kind`는 `env_temp_low` 같은 지표 종류이므로 알림 종류는
  /// 컬럼 [kind]로 본다.)
  String? get targetDeviceId {
    if (kind != envAlertNotificationKind) return null;
    final id = data['device_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// 카메라 렌즈 초점 안내가 가리키는 카메라(`cameras.id`). 운영자가
  /// `data.camera_id`로 넣는다(기획 2026-11-11 카메라 단위). 없으면(v1 사람 단위
  /// 행) null — 라이브 막대는 띄우지 않는다.
  String? get focusCameraId {
    if (kind != cameraFocusNotificationKind) return null;
    final id = data['camera_id'];
    return id is String && id.isNotEmpty ? id : null;
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
