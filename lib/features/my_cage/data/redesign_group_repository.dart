import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/redesign_management.dart';

typedef ManagementRowsLoader = Future<List<Map<String, Object?>>> Function(
    String table);
typedef ManagementRpc = Future<Object?> Function(
    String name, Map<String, Object?> params);

class ManagementFailure implements Exception {
  const ManagementFailure(this.key);
  final String key;
}

/// Existing tables are readable today. Writes require the separately reviewed
/// atomic redesign RPC contract; missing RPCs never fall back to direct writes.
class RedesignGroupRepository {
  RedesignGroupRepository(
      {required ManagementRowsLoader loadRows, required ManagementRpc rpc})
      : _loadRows = loadRows,
        _rpc = rpc;
  factory RedesignGroupRepository.supabase(
      SupabaseClient client, String userId) {
    void requireOwner() {
      if (client.auth.currentUser?.id != userId) {
        throw const ManagementFailure('management_auth_changed');
      }
    }

    return RedesignGroupRepository(loadRows: (table) async {
      requireOwner();
      final rows = await client
          .from(table)
          .select()
          .eq(table == 'pets' ? 'user_id' : 'owner_id', userId);
      requireOwner();
      return rows;
    }, rpc: (name, params) async {
      requireOwner();
      final Object? result = await client.rpc(name, params: params);
      requireOwner();
      return result;
    });
  }
  final ManagementRowsLoader _loadRows;
  final ManagementRpc _rpc;

  Future<ManagementInventory> load() async {
    final (groups, devices, cameras, pets) = await (
      _loadRows('enclosures'),
      _loadRows('devices'),
      _loadRows('cameras'),
      _loadRows('pets')
    ).wait;
    final sortedGroups = [...groups]..sort((a, b) =>
        (_text(a['created_at']) ?? '').compareTo(_text(b['created_at']) ?? ''));
    ManagementItem item(Map<String, Object?> row, ManagementKind kind) =>
        ManagementItem(
            key: ManagementKey(kind: kind, id: _required(row['id'])),
            name: _text(row['name']) ?? '',
            groupId: _text(row['enclosure_id']),
            hardwareId: _text(
                row[kind == ManagementKind.device ? 'device_id' : 'camera_id']),
            isOnline:
                row['is_online'] is bool ? row['is_online'] as bool : null,
            subtitle: kind == ManagementKind.pet ? _text(row['morph']) : null);
    return ManagementInventory(groups: [
      for (final row in sortedGroups)
        ManagementGroup(
            id: _required(row['id']),
            name: _required(row['name']),
            number:
                row['group_number'] is int ? row['group_number'] as int : null)
    ], items: [
      for (final row in devices) item(row, ManagementKind.device),
      for (final row in cameras) item(row, ManagementKind.camera),
      for (final row in pets)
        if (row['deleted_at'] == null) item(row, ManagementKind.pet)
    ]);
  }

  Future<String> saveGroup(GroupEditDraft draft,
      {required String requestId}) async {
    final Object? result = await _call('redesign_save_group_v1', {
      'p_group_id': draft.groupId,
      'p_name': draft.useDefaultName ? null : draft.name.trim(),
      for (final kind in ManagementKind.values)
        'p_${kind.name}_id':
            draft.members.where((key) => key.kind == kind).firstOrNull?.id,
      'p_expected_members': [
        for (final entry in draft.expectedGroups.entries)
          {
            'kind': entry.key.kind.name,
            'id': entry.key.id,
            'group_id': entry.value
          }
      ],
      'p_request_id': requestId,
    });
    if (result is! Map<String, Object?> || result['group_id'] is! String) {
      {
        throw const ManagementFailure('management_save_failed');
      }
    }
    return result['group_id']! as String;
  }

  Future<void> deleteGroup(String groupId, {required String requestId}) async {
    final result = await _call('redesign_delete_group_v1', {
      'p_group_id': groupId,
      'p_request_id': requestId,
    });
    if (result is! Map<String, Object?> ||
        result['group_id'] != groupId ||
        result['deleted'] != true) {
      throw const ManagementFailure('management_save_failed');
    }
  }

  Future<void> rename(ManagementKey key, String name) async {
    final result = await _call('redesign_rename_item_v1',
        {'p_kind': key.kind.name, 'p_item_id': key.id, 'p_name': name.trim()});
    if (result is! Map<String, Object?> || result['id'] != key.id) {
      {
        throw const ManagementFailure('management_save_failed');
      }
    }
  }

  Future<void> removeMember(ManagementKey key, String groupId,
      {required String requestId}) async {
    final result = await _call('redesign_remove_group_member_v1', {
      'p_kind': key.kind.name,
      'p_item_id': key.id,
      'p_expected_group_id': groupId,
      'p_request_id': requestId
    });
    if (result is! Map<String, Object?> || result['removed'] != true) {
      {
        throw const ManagementFailure('management_save_failed');
      }
    }
  }

  Future<void> unlink(ManagementKey key, {required String requestId}) async {
    final result = await _call('redesign_unlink_device_v1', {
      'p_kind': key.kind.name,
      'p_item_id': key.id,
      'p_request_id': requestId
    });
    if (result is! Map<String, Object?> || result['unlinked'] != true) {
      {
        throw const ManagementFailure('management_save_failed');
      }
    }
  }

  Future<Object?> _call(String name, Map<String, Object?> params) async {
    try {
      return await _rpc(name, params);
    } on PostgrestException catch (error) {
      if (['PGRST202', '42883', '0A000'].contains(error.code)) {
        {
          throw const ManagementFailure('management_server_unsupported');
        }
      }
      if (error.code == '23505') {
        throw const ManagementFailure('management_name_duplicate');
      }
      if (error.code == '40001') {
        throw const ManagementFailure('management_members_changed');
      }
      if (error.code == '42501') {
        throw const ManagementFailure('management_auth_changed');
      }
      throw const ManagementFailure('management_save_failed');
    }
  }

  static String? _text(Object? value) => value is String ? value : null;
  static String _required(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid management identity');
    }
    return value;
  }
}
