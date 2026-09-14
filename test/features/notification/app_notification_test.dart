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
}
