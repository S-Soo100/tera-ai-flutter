import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../domain/actuator_marker.dart';
import '../domain/day_window.dart';
import '../domain/env_extremes.dart';
import 'home_set_providers.dart';

/// 현재 세트 제어기 id. 없으면 null(캠 단품 등).
final currentDeviceIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  return set?.device?.id;
});

/// 당일(07:00~) 온습도 버킷. 최고/최저 산출용.
final todayBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final w = DayWindow.of(DateTime.now());
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, w.start, to: w.end);
});

/// 당일 최고/최저.
final todayExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  return EnvExtremes.from(await ref.watch(todayBucketsProvider.future));
});

/// 차트 구간(전날 19:00~현재) 온습도 버킷.
/// 당일 창([todayBucketsProvider])과 **다른 구간**이니 혼용하지 말 것.
final chartBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final r = DayWindow.chartRange(DateTime.now());
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, r.start, to: r.end);
});

/// `commands`에서 [from]~[to] 구간의 기기 동작 마커를 읽는다.
///
/// 홈 미니 차트와 통계 탭이 **서로 다른 구간**을 쓰므로 조회부를 함수로 빼 둔다
/// — 쿼리를 두 벌로 복사하면 한쪽만 고쳐진 채로 남는다.
///
/// 조회 실패는 빈 목록으로 흡수한다 — 마커가 없다고 차트를 못 그릴 이유는 없다.
Future<List<ActuatorMarker>> fetchActuatorMarkers(
  SupabaseClient client,
  String deviceId, {
  required DateTime from,
  required DateTime to,
}) async {
  try {
    final rows = await client
        .from('commands')
        .select('id, action, status, issued_at')
        .eq('device_id', deviceId)
        .gte('issued_at', from.toUtc().toIso8601String())
        .lte('issued_at', to.toUtc().toIso8601String());
    return ActuatorMarker.fromCommands(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  } catch (_) {
    return const [];
  }
}

/// 홈 차트 구간의 기기 동작 마커.
final actuatorMarkersProvider =
    FutureProvider.autoDispose<List<ActuatorMarker>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final r = DayWindow.chartRange(DateTime.now());
  return fetchActuatorMarkers(
    ref.watch(supabaseClientProvider),
    deviceId,
    from: r.start,
    to: r.end,
  );
});
