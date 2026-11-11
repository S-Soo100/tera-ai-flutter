import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/app_notification.dart';

abstract interface class NotificationStore {
  Stream<List<Map<String, Object?>>> watch(String userId);

  /// 한 종류의 알림만 실시간으로 본다. 행 범위는 RLS(본인 것만)가 정한다 —
  /// Realtime stream은 eq 필터를 하나만 받아 user_id 대신 kind로 거른다.
  Stream<List<Map<String, Object?>>> watchKind(String kind);
  Future<Map<String, Object?>?> findById(String id, String userId);
  Future<void> markRead(String id, String userId, DateTime at);
  Future<void> markAllRead(String userId, DateTime at);
}

class SupabaseNotificationStore implements NotificationStore {
  const SupabaseNotificationStore(this.client);
  final SupabaseClient client;

  @override
  Future<Map<String, Object?>?> findById(String id, String userId) => client
      .from('app_notifications')
      .select()
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle();

  @override
  Stream<List<Map<String, Object?>>> watch(String userId) => client
      .from('app_notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  /// 건수 제한을 두지 않는다 — Realtime stream은 `read_at is null`로 거를 수
  /// 없어 읽음 여부는 받은 뒤 거르는데, 초점 안내는 카메라 단위로 읽음 처리돼
  /// 오래된 미읽음이 다른 카메라 안내 뒤로 밀려나면 영영 안 뜬다. 운영자가 손으로
  /// 보내는 종류라 계정당 행이 적다.
  @override
  Stream<List<Map<String, Object?>>> watchKind(String kind) => client
      .from('app_notifications')
      .stream(primaryKey: ['id'])
      .eq('kind', kind)
      .order('created_at', ascending: false);

  @override
  Future<void> markRead(String id, String userId, DateTime at) async {
    await client
        .from('app_notifications')
        .update({'read_at': at.toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  @override
  Future<void> markAllRead(String userId, DateTime at) async {
    await client
        .from('app_notifications')
        .update({'read_at': at.toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }
}

class NotificationRepository {
  const NotificationRepository(this._store,
      {required String? Function() currentUserId})
      : _currentUserId = currentUserId;
  final NotificationStore _store;
  final String? Function() _currentUserId;

  Future<AppNotification?> findById(String id, String userId) async {
    if (id.isEmpty || _currentUserId() != userId) return null;
    final row = await _store.findById(id, userId);
    if (row == null || _currentUserId() != userId) return null;
    final item = AppNotification.fromJson(row);
    return item.id == id && item.userId == userId ? item : null;
  }

  Stream<List<AppNotification>> watchNotifications(String userId) =>
      _store.watch(userId).map((rows) {
        final items = rows
            .map(AppNotification.fromJson)
            .where((item) => item.userId == userId && item.id.isNotEmpty)
            .toList();
        items.sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));
        return List.unmodifiable(items);
      });

  /// [userId]의 읽지 않은 [kind] 알림. RLS만 믿지 않고 계정·읽음을 한 번 더 거른다.
  Stream<List<AppNotification>> watchUnreadOfKind(String userId, String kind) =>
      _store.watchKind(kind).map((rows) => List.unmodifiable(rows
          .map(AppNotification.fromJson)
          .where((item) =>
              item.userId == userId &&
              item.kind == kind &&
              item.id.isNotEmpty &&
              !item.isRead)));

  Future<void> markRead(String id) async {
    final userId = _currentUserId();
    if (userId == null || id.isEmpty) return;
    await _store.markRead(id, userId, DateTime.now().toUtc());
  }

  Future<void> markAllRead(String userId) async {
    if (_currentUserId() != userId) return;
    await _store.markAllRead(userId, DateTime.now().toUtc());
  }
}
