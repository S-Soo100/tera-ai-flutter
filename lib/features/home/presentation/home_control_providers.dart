import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../my_cage/domain/species_comfort.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../wiki/data/care_info_repository.dart';
import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/chart_window.dart';
import '../../../shared/domain/env_chart_data.dart';
import '../../../shared/domain/env_extremes.dart';
import '../../stats/domain/daily_rollup.dart';
import '../domain/hourly_env_slot.dart';
import '../domain/weekly_env_row.dart';
import 'home_set_providers.dart';

/// 현재 세트 제어기 id. 없으면 null(캠 단품 등).
final currentDeviceIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  return set?.device?.id;
});

/// 현재 세트 사육장 **종**에서 도출한 안심존. 종 미설정·미지원 종이면 null.
///
/// 사육장 탭의 [currentSpeciesComfortProvider]와 같은 규칙(care_info 실값만,
/// **임의 수치 없음**)이지만 기준이 다르다 — 저쪽은 사육장 탭의 선택 기기,
/// 여기는 홈이 보고 있는 세트다. 세트가 여럿이면 두 값이 다른 종일 수 있다.
///
/// 홈 "오늘 밤" 카드의 안정/주의 배지, 통계 주간 FIDS 표의 STATUS가 쓴다.
/// null이면 배지를 **생략**한다 — 모르는 것을 안정이라 말하지 않는다.
final currentSetComfortProvider =
    FutureProvider.autoDispose<SpeciesComfort?>((ref) async {
  // watch는 await 앞에서(이 파일 규칙).
  final careRepo = ref.watch(careInfoRepositoryProvider);
  final set = await ref.watch(currentSetProvider.future);
  final sid = speciesIdFromText(set?.enclosure.species);
  if (sid == null) return null;
  final care = await careRepo.getCareInfo(sid);
  return SpeciesComfort(
    speciesId: sid,
    speciesNameKo: care.speciesNameKo,
    tempMin: care.coolZone.min.toDouble(),
    tempMax: care.hotZone.max.toDouble(),
    humidMin: care.humidityMin.toDouble(),
    humidMax: care.humidityMax.toDouble(),
  );
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
/// 조회 끝은 창이 스스로 안다([ChartWindow.queryEnd]) — 과거 완결 창은
/// `end`, 진행 중 창은 `now`. 호출자가 고르게 두면 한쪽만 고쳐진 채 남는다.
Future<List<TelemetryBucket>> fetchChartBuckets(
  Ref ref,
  ChartWindow window,
) async {
  // watch는 반드시 await **앞에서** 한다(home_set_providers.dart 규칙) —
  // await 뒤의 watch는 dispose 후 continuation이 죽은 element에 걸린다.
  final repository = ref.watch(supabaseModuleControlRepositoryProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  return repository.telemetryHistory(deviceId, window.start,
      to: window.queryEnd);
}

/// 차트 창에 해당하는 온습도 버킷.
///
/// 당일 창([todayBucketsProvider])과 **다른 구간**이니 혼용하지 말 것.
final chartBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) {
  final w = ref.watch(chartWindowProvider);
  return fetchChartBuckets(ref, w);
});

/// 차트에 바로 그릴 수 있게 정리된 데이터.
///
/// x 정규화 기준은 **창 끝([ChartWindow.end], 미래)**이다. 지금까지로 잡으면
/// 선이 오른쪽 벽에 붙어 미도래 밴드가 들어갈 자리가 없어진다.
final envChartDataProvider =
    FutureProvider.autoDispose<EnvChartData>((ref) async {
  // watch를 await 앞으로 — fetchChartBuckets와 같은 이유.
  final w = ref.watch(chartWindowProvider);
  final buckets = await ref.watch(chartBucketsProvider.future);
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
  // watch를 await 앞으로 — fetchChartBuckets와 같은 이유.
  final w = ref.watch(chartWindowProvider);
  final client = ref.watch(supabaseClientProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  return fetchActuatorMarkers(client, deviceId, from: w.start, to: w.now);
});

// ── 홈 "지난 24시간" 스트립 · "이번 주" 행 (애플 날씨 문법, 2026-08-17) ──
//
// 홈은 통계 탭(연속 곡선 EnvChart)과 **다른 문법**을 쓴다 — 훑는 자리라
// 숫자와 바로 읽히는 리스트다. 데이터 창은 그대로 재사용한다.

/// 지난 24시간 스트립의 칸 목록. 창·버킷·마커는 24h 차트와 **같은 것**이다.
///
/// 실시간 온도는 위젯이 따로 [telemetryStreamProvider]에서 읽어 "지금" 칸에
/// 얹는다 — 여기서 스트림까지 물면 값이 올 때마다 24h 조립을 다시 한다.
final hourlyEnvSlotsProvider =
    FutureProvider.autoDispose<List<HourlyEnvSlot>>((ref) async {
  // watch를 await 앞으로 — fetchChartBuckets와 같은 이유.
  final w = ref.watch(chartWindowProvider);
  final buckets = await ref.watch(chartBucketsProvider.future);
  final markers = await ref.watch(actuatorMarkersProvider.future);
  return HourlyEnvSlots.build(now: w.now, buckets: buckets, markers: markers);
});

/// "이번 주" 창 — 오늘(진행 중) + 지난 6일. 화면이 살아 있는 동안 고정.
final homeWeeklyWindowProvider = Provider.autoDispose<ChartWindow>(
    (ref) => ChartWindow.homeWeekly(DateTime.now()));

/// "이번 주" 창의 30분 버킷 원본(최대 7×48행). 조회는 24h와 같은 한 벌.
final _homeWeeklyRawBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) {
  final w = ref.watch(homeWeeklyWindowProvider);
  return fetchChartBuckets(ref, w);
});

/// "이번 주" 창의 기기 마커(분무 횟수용). 조회 실패는 빈 목록 — 횟수 없다고
/// 온도 행을 못 그릴 이유는 없다([fetchActuatorMarkers]가 흡수).
final _homeWeeklyMarkersProvider =
    FutureProvider.autoDispose<List<ActuatorMarker>>((ref) async {
  final w = ref.watch(homeWeeklyWindowProvider);
  final client = ref.watch(supabaseClientProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  return fetchActuatorMarkers(client, deviceId, from: w.start, to: w.now);
});

/// "이번 주" 7행 — 오늘이 맨 위. 오늘 행은 07:00부터 지금까지의 min/max다.
///
/// 통계 탭 [weeklyDailyBucketsProvider]와 **다른 창**이다(저쪽은 오늘을 뺀
/// 완결 7일). 접기는 같은 [rollupByDay] 한 벌을 쓴다.
final homeWeeklyRowsProvider =
    FutureProvider.autoDispose<WeeklyEnvRows>((ref) async {
  final w = ref.watch(homeWeeklyWindowProvider);
  final raw = await ref.watch(_homeWeeklyRawBucketsProvider.future);
  final markers = await ref.watch(_homeWeeklyMarkersProvider.future);
  return WeeklyEnvRows.from(
    days: rollupByDay(raw, window: w),
    window: w,
    markers: markers,
  );
});
