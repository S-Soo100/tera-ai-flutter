import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../my_cage/presentation/supabase_module_providers.dart';
import '../domain/env_realtime_values.dart';

/// 기기 한 대의 현재 온습도 — 마지막 정상값을 쥐고 **지우지 않는다**
/// (`env_realtime_values.dart`). 텔레메트리 스트림의 행마다 [EnvLiveReading.next]로
/// 반영하고, 첫 값은 정상 행 최신값으로 채운다(최신 1행은 실패 행일 수 있다).
final envLiveProvider = NotifierProvider.autoDispose
    .family<EnvLiveNotifier, EnvLiveReading?, String>(EnvLiveNotifier.new);

class EnvLiveNotifier
    extends AutoDisposeFamilyNotifier<EnvLiveReading?, String> {
  bool _disposed = false;

  @override
  EnvLiveReading? build(String deviceId) {
    ref.onDispose(() => _disposed = true);
    ref.listen(telemetryStreamProvider(deviceId), (_, next) {
      final row = next.valueOrNull;
      if (row == null) return;
      state = (state ?? EnvLiveReading(deviceId: deviceId)).next(row);
    });
    unawaited(_seed(deviceId));
    return null;
  }

  Future<void> _seed(String deviceId) async {
    try {
      final good = await ref
          .read(supabaseModuleControlRepositoryProvider)
          .latestGoodTelemetry(deviceId);
      if (good == null || _disposed) return;
      // 스트림이 먼저 새 정상값을 채웠으면 그대로 둔다(next가 옛 행을 거른다).
      final base = state ?? EnvLiveReading(deviceId: deviceId);
      final merged = base.next(good);
      state = EnvLiveReading(
          deviceId: deviceId,
          temperature: merged.temperature,
          humidity: merged.humidity,
          measuredAt: merged.measuredAt,
          consecutiveFaults: base.consecutiveFaults);
    } catch (_) {/* 스트림 값으로 채워진다. */}
  }
}

/// "N초 전"을 늘리는 5초 주기 시계 — 값이 오래됐을 때만 화면이 쓴다.
final envAgeTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 5), (_) => DateTime.now());
});

/// 화면에 그릴 현재 온습도 — 신선도는 서버 `is_online`과 측정 경과로 정한다.
final envLiveViewProvider =
    Provider.autoDispose.family<EnvLiveView, String>((ref, deviceId) {
  final reading = ref.watch(envLiveProvider(deviceId));
  final now = ref.watch(envAgeTickProvider).valueOrNull ?? DateTime.now();
  final online =
      ref.watch(deviceLinkStatusProvider(deviceId)).valueOrNull?.isOnline;
  return envLiveView(reading, now: now, online: online);
});

/// 신선도 안내 한 줄 — 신선하면 null(아무 변화 없음). 우선순위: 오프라인 >
/// 센서 오류 > 오래됨.
String? envLiveCaption(EnvLiveView view) {
  switch (view.freshness) {
    case EnvFreshness.offline:
      final at = view.measuredAt;
      return at == null
          ? 'env_live_offline'.tr()
          : 'env_live_offline_since'.tr(args: [DateFormat('HH:mm').format(at)]);
    case EnvFreshness.aging:
      if (view.sensorError) return 'env_live_sensor_error'.tr();
      final seconds = view.age.inSeconds;
      return seconds < 60
          ? 'env_live_age_seconds'.tr(args: ['$seconds'])
          : 'env_live_age_minutes'.tr(args: ['${view.age.inMinutes}']);
    case EnvFreshness.fresh:
      return view.sensorError ? 'env_live_sensor_error'.tr() : null;
  }
}
