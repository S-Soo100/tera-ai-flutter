import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/auto_env.dart';
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

  /// 자동 환기·분무 토글 저장(계약 C1). [save]처럼 낙관적 반영은 없다.
  ///
  /// - 응답의 해당 값이 보낸 값과 다르면 [AutoEnvSaveMismatch]를 던지고 상태는
  ///   그대로 둔다 — 마이그레이션 전 서버는 모르는 필드를 무시하고 200을
  ///   주므로, 응답을 그대로 넣으면 스위치가 아무 안내 없이 꺼짐으로 돌아간다.
  /// - 저장하는 동안 `keepAlive`로 붙잡는다(autoDispose). 저장 중 시트를
  ///   닫아도 요청이 끝나기 전에 버려져 상태 대입이 터지지 않게 하려는 것.
  Future<void> saveAuto({bool? vent, bool? mist}) async {
    if (vent == null && mist == null) return;
    final repo = ref.read(deviceSettingsRepositoryProvider);
    final link = ref.keepAlive();
    try {
      final updated = await repo.patch(
        arg,
        autoVentEnabled: vent,
        autoMistEnabled: mist,
      );
      if ((vent != null && updated.autoVentEnabled != vent) ||
          (mist != null && updated.autoMistEnabled != mist)) {
        throw const AutoEnvSaveMismatch();
      }
      state = AsyncData(updated);
    } finally {
      link.close();
    }
  }
}
