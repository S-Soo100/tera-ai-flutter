import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/chart_window.dart';
import '../../../shared/domain/env_chart_data.dart';
import '../../../shared/domain/env_extremes.dart';
import 'home_set_providers.dart';

/// 현재 세트 제어기 id. 없으면 null(캠 단품 등).
final currentDeviceIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  return set?.device?.id;
});

/// 온습도 차트의 표시 창([ChartWindow]).
///
/// **홈과 통계가 같은 창을 쓴다.** 홈 차트를 눌러 통계로 넘어갔을 때 다른
/// 구간이 나오면 "방금 본 그래프"가 아니게 된다.
///
/// 화면이 살아 있는 동안 고정이다 — 1초마다 다시 잡으면 눈금과 회색 밴드가
/// 미세하게 떨려서 읽을 수 없다. 6시간마다 전진하는 프레임이라 화면을 다시
/// 열면 알아서 최신으로 잡힌다.
final chartWindowProvider =
    Provider.autoDispose<ChartWindow>((ref) => ChartWindow.of(DateTime.now()));

/// [window] 구간의 30분 버킷을 조회한다. **일간·주간이 같은 조회를 쓴다** —
/// 쿼리를 두 벌로 복사하면 한쪽만 고쳐진 채로 남는다(마커 조회부와 같은 이유).
///
/// [to]는 창마다 의미가 달라 **호출자가 명시한다**:
/// - 일간(`ChartWindow.of`)은 `w.now` — 창 끝이 미래라, 없는 시간을 물어볼
///   이유가 없다.
/// - 주간(`ChartWindow.weekly`)은 `w.end` — 창 전체가 과거(직전 07:00까지)라
///   `now`까지 당기면 진행 중인 오늘 몫이 딸려와 rollup이 도로 버린다.
Future<List<TelemetryBucket>> fetchChartBuckets(
  Ref ref,
  ChartWindow window, {
  required DateTime to,
}) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, window.start, to: to);
}

/// 차트 창에 해당하는 온습도 버킷.
///
/// 당일 창([todayBucketsProvider])과 **다른 구간**이니 혼용하지 말 것.
final chartBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) {
  final w = ref.watch(chartWindowProvider);
  return fetchChartBuckets(ref, w, to: w.now);
});

/// 차트에 바로 그릴 수 있게 정리된 데이터.
///
/// x 정규화 기준은 **창 끝([ChartWindow.end], 미래)**이다. 지금까지로 잡으면
/// 선이 오른쪽 벽에 붙어 미도래 밴드가 들어갈 자리가 없어진다.
final envChartDataProvider =
    FutureProvider.autoDispose<EnvChartData>((ref) async {
  final buckets = await ref.watch(chartBucketsProvider.future);
  final w = ref.watch(chartWindowProvider);
  return EnvChartData.from(buckets, from: w.start, to: w.end);
});

/// 차트가 보여주는 구간의 최고/최저.
///
/// **차트와 같은 창을 쓴다.** 요약의 숫자는 바로 아래 그래프를 설명하는 값이라,
/// 다른 창을 쓰면 서로 어긋난다 — 당일(07:00~) 창을 쓰던 동안, 그래프에는
/// 27~32℃ 곡선이 그려져 있는데 최고/최저는 `--`로 뜨는 화면이 실기기에서 나왔다.
final chartExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  return EnvExtremes.from(await ref.watch(chartBucketsProvider.future));
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

/// 차트 창의 기기 동작 마커.
final actuatorMarkersProvider =
    FutureProvider.autoDispose<List<ActuatorMarker>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final w = ref.watch(chartWindowProvider);
  return fetchActuatorMarkers(
    ref.watch(supabaseClientProvider),
    deviceId,
    from: w.start,
    to: w.now,
  );
});
