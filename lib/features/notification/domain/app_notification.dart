import 'notification_route.dart';

/// v4 온습도 이탈 푸시(terra-server `docs/APP_ENV_ALERT_PUSH_2026-11-02.md` §2).
const envAlertNotificationKind = 'env.alert.triggered';

/// 운영자가 특정 카메라에 보내는 렌즈 초점 안내(카메라 단위, 푸시 없음).
/// 운영자가 SQL로 app_notifications에 직접 넣는다 — `docs/ops/camera-focus-notice.md`.
const cameraFocusNotificationKind = 'camera.focus_needed';

/// 카메라 Wi-Fi 신호가 10분 넘게 약할 때 서버가 넣는 안내(카메라 단위, 푸시 없음).
/// 회복하면 서버가 `read_at`을 채운다 — terra-server
/// `docs/APP_CAMERA_WEAK_SIGNAL_2026-11-13.md`, 앱 기획
/// `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`.
const cameraWeakSignalNotificationKind = 'camera.weak_signal';

/// 라이브 위 막대로 보이는 카메라 단위 안내 — **앞일수록 먼저**. 같은 카메라에
/// 둘 다 미읽음이면 신호 안내를 먼저 띄우고, 사라지면 초점 안내가 이어 뜬다(D3).
const liveNoticeKinds = [
  cameraWeakSignalNotificationKind,
  cameraFocusNotificationKind,
];

/// 종류별 실시간 구독(`watchKind`)이 받는 최근 행 수 상한. 신호 약함은 서버가
/// 자동으로 넣어(카메라당 하루 1건) 행이 계속 쌓인다. 서버는 카메라마다 안 읽은
/// 행이 있으면 새로 넣지 않으므로 미읽음은 카메라당 최대 1건이고, 최근 100건이면
/// 카메라 여럿의 미읽음이 밀려나지 않는다. 운영자가 손으로 넣는 초점 안내는
/// 상한이 없다(오래된 미읽음이 밀려나면 영영 안 뜬다).
const notificationKindStreamLimit = {cameraWeakSignalNotificationKind: 100};

/// 알림함 목록·미읽음 수·"모두 읽음"에서 빼는 종류 — 막대에만 보인다.
const inboxHiddenNotificationKinds = {cameraWeakSignalNotificationKind};

const knownNotificationKinds = {
  cameraFocusNotificationKind,
  cameraWeakSignalNotificationKind,
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

  /// 카메라 렌즈 초점 안내가 가리키는 카메라 표시들 — `data.camera_id`와
  /// `data.device_id`. 지정 방법은 서버가 정하므로(기획 2026-11-11 Q2)
  /// `cameras.id`(uuid)든 기기 ID(`cameras.camera_id`)든 받는다. 비어 있으면(v1
  /// 사람 단위 행) 라이브 막대는 띄우지 않는다.
  Set<String> get focusCameraRefs =>
      kind == cameraFocusNotificationKind ? liveCameraRefs : const {};

  /// 라이브 막대 안내([liveNoticeKinds])가 가리키는 카메라 표시들 — 위와 같은
  /// 규칙. 다른 종류면 빈 집합.
  Set<String> get liveCameraRefs {
    if (!liveNoticeKinds.contains(kind)) return const {};
    return {
      for (final key in const ['camera_id', 'device_id'])
        if (data[key] case final String id when id.isNotEmpty) id,
    };
  }

  /// 이 초점 안내가 [cameraId](`cameras.id`)·[deviceId](기기 ID) 카메라를 가리키는가.
  bool focusTargets(String cameraId, String deviceId) {
    final refs = focusCameraRefs;
    return refs.contains(cameraId) || refs.contains(deviceId);
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
