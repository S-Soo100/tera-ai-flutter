import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';

void main() {
  test('unknown kind remains visible but cannot navigate to a known route', () {
    final item = AppNotification.fromJson({
      'id': 'n1',
      'user_id': 'u1',
      'kind': 'future.kind',
      'category': 'other',
      'title': '제목',
      'body': '본문',
      'route': '/env-detail',
      'data': <String, Object?>{'future': 42},
      'created_at': '2026-09-15T12:00:00Z',
      'read_at': null,
    });
    expect(item.title, '제목');
    expect(item.body, '본문');
    expect(item.data['future'], 42);
    expect(item.isRead, isFalse);
    expect(item.safeRoute, '/notifications');
    expect(item.category, 'other');
    expect(() => item.data['future'] = 0, throwsUnsupportedError);
  });

  test('malformed optional fields do not crash and known kinds route safely',
      () {
    final item = AppNotification.fromJson({
      'id': 'n2',
      'user_id': 'u1',
      'kind': 'safety.alert',
      'category': 'safety',
      'title': 123,
      'body': null,
      'data': ['bad'],
      'route': '/env-detail',
      'created_at': 'bad',
      'read_at': 1,
    });
    expect(item.title, '');
    expect(item.body, '');
    expect(item.data, isEmpty);
    expect(item.createdAt, isNull);
    expect(item.isRead, isFalse);
    expect(item.safeRoute, '/env-detail');
  });

  // v4 온습도 이탈 푸시(env.alert.triggered, 2026-11-02). data는 서버 트리거가
  // payload를 합친 것이라 data.kind는 env_temp_low 같은 지표 종류다.
  Map<String, Object?> envRow({Object? deviceId = 'dev-1'}) => {
        'id': 'n3',
        'user_id': 'u1',
        'kind': 'env.alert.triggered',
        'category': 'env',
        'title': '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요',
        'body': '거실 사육장',
        'route': '/env-detail',
        'data': <String, Object?>{
          'kind': 'env_temp_low',
          'level': 'danger',
          if (deviceId != null) 'device_id': deviceId,
        },
      };

  test('env alert is a known kind that routes to env detail', () {
    final item = AppNotification.fromJson(envRow());
    expect(knownNotificationKinds, contains('env.alert.triggered'));
    expect(item.kind, 'env.alert.triggered');
    expect(item.category, 'env');
    expect(item.safeRoute, '/env-detail');
    expect(item.title, '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요');
    expect(item.body, '거실 사육장');
  });

  test('only env alerts expose a non-empty string device_id as target', () {
    expect(AppNotification.fromJson(envRow()).targetDeviceId, 'dev-1');
    expect(AppNotification.fromJson(envRow(deviceId: null)).targetDeviceId,
        isNull);
    expect(
        AppNotification.fromJson(envRow(deviceId: '')).targetDeviceId, isNull);
    expect(
        AppNotification.fromJson(envRow(deviceId: 42)).targetDeviceId, isNull);
    final safety = AppNotification.fromJson({
      ...envRow(),
      'kind': 'safety.alert',
      'category': 'safety',
    });
    expect(safety.targetDeviceId, isNull);
  });

  test('env alerts and safety kinds use the high-importance channel', () {
    expect(usesSafetyChannel('env.alert.triggered'), isTrue);
    expect(usesSafetyChannel('safety.alert'), isTrue);
    expect(usesSafetyChannel('device.action.failed'), isFalse);
    expect(usesSafetyChannel('highlight.ready'), isFalse);
  });
}
