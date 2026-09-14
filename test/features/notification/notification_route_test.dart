import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/domain/notification_route.dart';

void main() {
  test('only exact approved routes and UUID post paths may navigate', () {
    for (final route in [
      '/notifications',
      '/crecam/highlights',
      '/home/routines',
      '/env-detail',
      '/community-player/4da7f48b-0000-4000-8000-111111111111'
    ]) {
      expect(sanitizeNotificationRoute(route), route);
    }
    for (final route in [
      null,
      '',
      'https://evil.example',
      '//evil.example',
      '/profile',
      '/env-detail?next=/profile',
      '/env-detail/',
      '/community-player/not-an-id',
      '/community-player/4da7f48b-0000-4000-8000-111111111111/extra',
      '/%65nv-detail'
    ]) {
      expect(sanitizeNotificationRoute(route), '/notifications');
    }
  });
}
