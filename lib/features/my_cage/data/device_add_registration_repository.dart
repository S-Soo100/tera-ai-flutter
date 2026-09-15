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
}
