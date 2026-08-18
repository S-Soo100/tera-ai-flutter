import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_settings_repository.dart';
import '../domain/device_settings.dart';

/// 기기별 목표 환경. autoDispose — 화면을 벗어나면 버리고, 들어올 때 다시
/// 읽어 다른 기기·웹 콘솔에서 바꾼 값이 반영되게 한다. 저장은
/// [DeviceSettingsNotifier.save]로 하고 결과를 그대로 상태에 넣는다.
final deviceSettingsProvider = AsyncNotifierProvider.autoDispose
    .family<DeviceSettingsNotifier, DeviceSettings, String>(
  DeviceSettingsNotifier.new,
);

class DeviceSettingsNotifier
    extends AutoDisposeFamilyAsyncNotifier<DeviceSettings, String> {
  @override
  Future<DeviceSettings> build(String arg) =>
      ref.watch(deviceSettingsRepositoryProvider).get(arg);

  /// 낙관적 업데이트는 하지 않는다 — 서버가 400으로 거부한 목표를 화면에
  /// 반영된 것처럼 보이면 사용자는 기기가 그 값을 따르는 줄 안다.
  Future<void> save({double? targetTempC, double? targetHumidityPct}) async {
    final updated = await ref.read(deviceSettingsRepositoryProvider).patch(
          arg,
          targetTempC: targetTempC,
          targetHumidityPct: targetHumidityPct,
        );
    state = AsyncData(updated);
  }
}
