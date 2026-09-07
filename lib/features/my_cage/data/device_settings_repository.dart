import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/terra_rest_client.dart';
import '../domain/device_settings.dart';

/// 기기 목표 환경(setpoint) REST (2026-08-18 회신 §5). **REST 전용** —
/// 서버가 소유권·범위를 검증하고 펌웨어에 내려보내는 걸 한 곳에서 처리한다.
class DeviceSettingsRepository {
  final TerraRestClient _client;

  DeviceSettingsRepository(this._client);

  /// 미설정이어도 200(전부 null). 남의 기기는 404 → [TerraRestException].
  Future<DeviceSettings> get(String deviceId) async {
    final decoded = await _client.get('/devices/$deviceId/settings');
    if (decoded is! Map) return DeviceSettings(deviceId: deviceId);
    return DeviceSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// 부분 수정(없으면 생성). 보낸 필드만 갱신된다.
  Future<DeviceSettings> patch(
    String deviceId, {
    double? targetTempC,
    double? targetHumidityPct,
  }) async {
    final decoded = await _client.patch(
      '/devices/$deviceId/settings',
      DeviceSettings.patchBody(
        targetTempC: targetTempC,
        targetHumidityPct: targetHumidityPct,
      ),
    );
    return DeviceSettings.fromJson(Map<String, dynamic>.from(decoded as Map));
  }
}

final deviceSettingsRepositoryProvider =
    Provider<DeviceSettingsRepository>((ref) {
  return DeviceSettingsRepository(ref.watch(terraRestClientProvider));
});
