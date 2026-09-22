import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/terra_rest_client.dart';
import '../domain/redesign_management.dart';

typedef ManagementRowsLoader = Future<List<Map<String, Object?>>> Function(
    String table);
typedef ManagementRpc = Future<Object?> Function(
    String name, Map<String, Object?> params);

/// 기기 등록 해제(소프트 해제) 호출. 2026-09-16 가정 계약 — terra-server
/// `POST /devices/{uuid}/unlink` · `POST /cameras/{uuid}/unlink`, body
/// `{"request_id": uuid}`. 서버가 `unlinked_at`을 찍고 MQTT 계정을 회수하며
/// 원본 기록(영상·텔레메트리·소유권)은 보존한다(회신 2026-09-15 §2.5).
typedef ManagementUnlink = Future<void> Function(
    ManagementKind kind, String id, String requestId);

class ManagementFailure implements Exception {
  const ManagementFailure(this.key);
  final String key;
}

/// Existing tables are readable today. Writes require the separately reviewed
/// atomic redesign RPC contract; missing RPCs never fall back to direct writes.
class RedesignGroupRepository {
  RedesignGroupRepository(
      {required ManagementRowsLoader loadRows,
      required ManagementRpc rpc,
      ManagementUnlink? unlink,
      this.rpcTimeout = const Duration(seconds: 20)})
      : _loadRows = loadRows,
        _rpc = rpc,
        _unlink = unlink;
  factory RedesignGroupRepository.supabase(SupabaseClient client, String userId,
      {TerraRestClient? rest}) {
    void requireOwner() {
      if (client.auth.currentUser?.id != userId) {
        throw const ManagementFailure('management_auth_changed');
      }
    }

    return RedesignGroupRepository(
        loadRows: (table) async {
          requireOwner();
          final rows = await client
              .from(table)
              .select()
              .eq(table == 'pets' ? 'user_id' : 'owner_id', userId);
          requireOwner();
          return rows;
        },
        rpc: (name, params) async {
          requireOwner();
          final Object? result = await client.rpc(name, params: params);
          requireOwner();
          return result;
        },
        unlink: rest == null
            ? null
            : (kind, id, requestId) async {
                requireOwner();
                final segment = switch (kind) {
                  ManagementKind.device => 'devices',
                  ManagementKind.camera => 'cameras',
                  ManagementKind.pet =>
                    throw const ManagementFailure('management_save_failed'),
                };
                await rest.post('/$segment/$id/unlink', {
                  'request_id': requestId,
                });
                requireOwner();
              });
  }
  final ManagementRowsLoader _loadRows;
  final ManagementRpc _rpc;
  final ManagementUnlink? _unlink;

  /// 쓰기 RPC 응답 대기 상한. 서버가 40001을 내면 PostgREST가 그 트랜잭션을
  /// 끝없이 재시도해 응답이 영영 안 온다(2026-09-22 운영에서 확인). 그동안
  /// 버튼이 잠긴 채 멈추지 않도록 끊는다. 서버에선 반영됐을 수도 있으니 실패가
  /// 아니라 '확인 필요'로 알린다 — 같은 request_id로 다시 보내면 멱등이다.
  final Duration rpcTimeout;

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
      // 소프트 해제된 기기(`unlinked_at` 있음)는 뺀다 — 회신 §2.5 "목록 조회에서
      // 해제된 기기를 제외". 컬럼이 아직 없으면 null이라 전부 남는다.
      for (final row in devices)
        if (row['unlinked_at'] == null) item(row, ManagementKind.device),
      for (final row in cameras)
        if (row['unlinked_at'] == null) item(row, ManagementKind.camera),
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

  /// 기기 등록 해제 — terra-server REST(소프트 해제)만 쓴다. 직접 DELETE나
  /// 테이블 UPDATE로 우회하지 않는다(hard delete는 기록을 cascade 삭제한다).
  Future<void> unlink(ManagementKey key, {required String requestId}) async {
    final unlink = _unlink;
    if (unlink == null) {
      throw const ManagementFailure('management_server_unsupported');
    }
    try {
      await unlink(key.kind, key.id, requestId);
    } on ManagementFailure {
      rethrow;
    } on TerraRestException catch (error) {
      // 404/405: 해제 endpoint 미배포(또는 소유 아님 — 서버는 소유권 위반도 404).
      if (error.statusCode == 404 || error.statusCode == 405) {
        throw const ManagementFailure('management_server_unsupported');
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        throw const ManagementFailure('management_auth_changed');
      }
      throw const ManagementFailure('management_save_failed');
    } catch (_) {
      throw const ManagementFailure('management_save_failed');
    }
  }

  Future<Object?> _call(String name, Map<String, Object?> params) async {
    try {
      return await _rpc(name, params).timeout(rpcTimeout);
    } on TimeoutException {
      throw const ManagementFailure('management_save_timeout');
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
