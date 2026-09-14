/// Push payloads are untrusted: accept only exact app destinations.
String sanitizeNotificationRoute(String? route) {
  const allowed = {
    '/notifications',
    '/crecam/highlights',
    '/home/routines',
    '/env-detail'
  };
  if (allowed.contains(route)) return route!;
  if (route != null &&
      RegExp(r'^/community-player/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(route)) {
    return route;
  }
  return '/notifications';
}
