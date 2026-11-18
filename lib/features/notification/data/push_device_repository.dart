import 'package:flutter/foundation.dart';

/// 서버 `register_push_device`의 `p_platform` 값(`android`/`ios`만 받는다). FCM은
/// Android·iOS에서만 켜지므로 그 밖의 플랫폼은 등록까지 오지 않는다.
String pushPlatformName([TargetPlatform? platform]) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
        ? 'ios'
        : 'android';

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
    String Function() platform = pushPlatformName,
  })  : _rpc = rpc,
        _currentUserId = currentUserId,
        _platform = platform;
  final Future<void> Function(String, Map<String, Object?>) _rpc;
  final String? Function() _currentUserId;
  final String Function() _platform;

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
      'p_platform': _platform(),
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
