abstract interface class PushDevicePort {
  Future<void> register(
      {required String userId,
      required String installationId,
      required String token,
      required String appVersion,
      required String locale});
  Future<void> deactivate(String installationId);
}

class PushDeviceRepository implements PushDevicePort {
  const PushDeviceRepository({
    required Future<void> Function(String, Map<String, Object?>) rpc,
    required String? Function() currentUserId,
  })  : _rpc = rpc,
        _currentUserId = currentUserId;
  final Future<void> Function(String, Map<String, Object?>) _rpc;
  final String? Function() _currentUserId;

  @override
  Future<void> register(
      {required String userId,
      required String installationId,
      required String token,
      required String appVersion,
      required String locale}) async {
    if (_currentUserId() != userId || token.trim().isEmpty) return;
    await _rpc('register_push_device', {
      'p_installation_id': installationId,
      'p_fcm_token': token,
      'p_platform': 'android',
      'p_app_version': appVersion,
      'p_locale': locale,
    });
  }

  @override
  Future<void> deactivate(String installationId) async {
    if (_currentUserId() == null) return;
    await _rpc('deactivate_push_device', {'p_installation_id': installationId});
  }
}
