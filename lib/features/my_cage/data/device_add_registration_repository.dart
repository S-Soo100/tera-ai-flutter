import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/pair_target_kind.dart';

/// Read-only confirmation of the firmware's PAIR_OK identifier. The app never
/// calls /pair, inserts a device, guesses an ID, or infers kind from its prefix.
class DeviceAddRegistrationRepository {
  DeviceAddRegistrationRepository(this.client,
      {String? Function()? accountIdProvider})
      : _accountId = accountIdProvider ?? (() => client.auth.currentUser?.id);
  final SupabaseClient client;
  final String? Function() _accountId;
  void _guard(String account) {
    if (_accountId() != account) {
      throw StateError('Account changed');
    }
  }

  Future<List<String>> names(String account) async {
    _guard(account);
    final devices =
        await client.from('devices').select('name').eq('owner_id', account);
    _guard(account);
    final cameras =
        await client.from('cameras').select('name').eq('owner_id', account);
    _guard(account);
    return [
      for (final row in [...devices, ...cameras])
        if (row['name'] case final String name) name
    ];
  }

  Future<String?> confirm(
      String account, PairTargetKind kind, String hardwareId) async {
    _guard(account);
    final isCamera = kind == PairTargetKind.camera;
    final rows = await client
        .from(isCamera ? 'cameras' : 'devices')
        .select('id')
        .eq('owner_id', account)
        .eq(isCamera ? 'camera_id' : 'device_id', hardwareId)
        .limit(2);
    _guard(account);
    if (rows.length != 1) return null;
    final id = rows.single['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// 이 계정의 카메라 행이 아직 있으면 마지막 접속 시각과 함께 돌려준다.
  /// 삭제·해제(`unlinked_at`)됐거나 다른 계정으로 넘어갔으면 null — 새로
  /// 등록해야 한다(해제된 행으로 Wi-Fi만 붙이면 목록에 안 보인다).
  Future<({DateTime? lastSeen})?> ownedCamera(String account, String id) async {
    _guard(account);
    final rows = await client
        .from('cameras')
        .select('id,last_seen_at,unlinked_at')
        .eq('owner_id', account)
        .eq('id', id)
        .limit(1);
    _guard(account);
    if (rows.isEmpty || rows.single['unlinked_at'] != null) return null;
    final raw = rows.single['last_seen_at'];
    return (lastSeen: raw == null ? null : DateTime.tryParse(raw.toString()));
  }

  /// 이 계정의 사육장 행이 해제 없이 남아 있는지 — 스캔 목록 '이미 등록됨'용.
  Future<bool> ownedDevice(String account, String id) async {
    _guard(account);
    final rows = await client
        .from('devices')
        .select('id')
        .eq('owner_id', account)
        .eq('id', id)
        .isFilter('unlinked_at', null)
        .limit(1);
    _guard(account);
    return rows.isNotEmpty;
  }
}
