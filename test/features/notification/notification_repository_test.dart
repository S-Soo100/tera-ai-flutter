import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';

class MemoryNotificationStore implements NotificationStore {
  final rows = <Map<String, Object?>>[];
  final changes = StreamController<void>.broadcast();
  final operations = <String>[];

  @override
  Future<Map<String, Object?>?> findById(String id, String userId) async {
    operations.add('find:$id:$userId');
    for (final row in rows) {
      if (row['id'] == id && row['user_id'] == userId) return row;
    }
    return null;
  }

  @override
  Stream<List<Map<String, Object?>>> watch(String userId) async* {
    yield rows.where((r) => r['user_id'] == userId).toList();
    await for (final _ in changes.stream) {
      yield rows.where((r) => r['user_id'] == userId).toList();
    }
  }

  @override
  Future<void> markRead(String id, String userId, DateTime at) async {
    operations.add('read:$id:$userId');
    for (final row
        in rows.where((r) => r['id'] == id && r['user_id'] == userId)) {
      row['read_at'] ??= at.toIso8601String();
    }
    changes.add(null);
  }

  @override
  Future<void> markAllRead(String userId, DateTime at) async {
    operations.add('all:$userId');
    for (final row in rows.where((r) => r['user_id'] == userId)) {
      row['read_at'] ??= at.toIso8601String();
    }
    changes.add(null);
  }
}

class DelayedNotificationStore extends MemoryNotificationStore {
  final result = Completer<Map<String, Object?>?>();
  @override
  Future<Map<String, Object?>?> findById(String id, String userId) =>
      result.future;
}

Map<String, Object?> notificationRow(String id, String userId, String at) => {
      'id': id,
      'user_id': userId,
      'created_at': at,
      'read_at': null,
      'title': id,
      'body': '본문',
      'kind': 'safety.alert',
      'category': 'safety',
      'route': '/env-detail',
      'data': <String, Object?>{},
    };

User notificationUser(String id) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-09-15T00:00:00Z');

void main() {
  test('Supabase single lookup sends notification ID and account filters',
      () async {
    final requests = <Uri>[];
    final client = SupabaseClient('https://example.test', 'test-anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
          jsonEncode(request.url.queryParameters['id'] == 'eq.n1'
              ? [notificationRow('n1', 'a', '2026-09-15T00:00:00Z')]
              : []),
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final store = SupabaseNotificationStore(client);
    expect((await store.findById('n1', 'a'))?['id'], 'n1');
    expect(requests.single.path, '/rest/v1/app_notifications');
    expect(requests.single.queryParameters['id'], 'eq.n1');
    expect(requests.single.queryParameters['user_id'], 'eq.a');
    expect(await store.findById('missing', 'a'), isNull);
  });

  test('single lookup rejects account mismatch before query', () async {
    final store = MemoryNotificationStore();
    addTearDown(store.changes.close);
    store.rows.add(notificationRow('n1', 'a', '2026-09-15T00:00:00Z'));
    final repo = NotificationRepository(store, currentUserId: () => 'a');
    expect((await repo.findById('n1', 'a'))?.id, 'n1');
    expect(await repo.findById('n1', 'b'), isNull);
    expect(await repo.findById('', 'a'), isNull);
    expect(store.operations, ['find:n1:a']);
  });

  test(
      'single lookup rejects a stale account response and mismatched row identity',
      () async {
    String? userId = 'a';
    final store = DelayedNotificationStore();
    addTearDown(store.changes.close);
    final repo = NotificationRepository(store, currentUserId: () => userId);
    final pending = repo.findById('n1', 'a');
    userId = 'b';
    store.result.complete(notificationRow('n1', 'a', '2026-09-15T00:00:00Z'));
    expect(await pending, isNull);
    userId = 'a';
    expect(await repo.findById('other-id', 'a'), isNull);
    userId = 'b';
    expect(await repo.findById('n1', 'b'), isNull);
  });

  test('newest first, selected row only, mark all remains account scoped',
      () async {
    final store = MemoryNotificationStore();
    addTearDown(store.changes.close);
    store.rows.addAll([
      notificationRow('old', 'a', '2026-09-14T00:00:00Z'),
      notificationRow('other', 'b', '2026-09-15T00:00:00Z'),
      notificationRow('new', 'a', '2026-09-15T00:00:00Z'),
    ]);
    final repo = NotificationRepository(store, currentUserId: () => 'a');
    expect((await repo.watchNotifications('a').first).map((n) => n.id),
        ['new', 'old']);
    await repo.markRead('old');
    expect(store.operations, ['read:old:a']);
    expect(store.rows.first['read_at'], isNotNull);
    expect(store.rows.last['read_at'], isNull);
    await repo.markAllRead('a');
    expect(store.rows[1]['read_at'], isNull);
    expect((await repo.watchNotifications('a').first).where((n) => !n.isRead),
        isEmpty);
  });

  test(
      'switching accounts drops old rows immediately, including pending streams',
      () async {
    final store = MemoryNotificationStore();
    addTearDown(store.changes.close);
    store.rows.add(notificationRow('private-a', 'a', '2026-09-15T00:00:00Z'));
    User? user = notificationUser('a');
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => user),
      notificationRepositoryProvider.overrideWithValue(
          NotificationRepository(store, currentUserId: () => user?.id)),
    ]);
    addTearDown(container.dispose);
    container.listen(notificationsProvider, (_, __) {});
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadNotificationCountProvider), 1);
    user = notificationUser('b');
    container.invalidate(currentUserProvider);
    expect(container.read(notificationsProvider).valueOrNull ?? [], isEmpty);
    expect(container.read(unreadNotificationCountProvider), 0);
    await container.pump();
    user = null;
    container.invalidate(currentUserProvider);
    expect(container.read(notificationsProvider).requireValue, isEmpty);
    expect(container.read(unreadNotificationCountProvider), 0);
  });
}
