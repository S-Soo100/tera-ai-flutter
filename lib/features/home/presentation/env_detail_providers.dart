import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/control_log.dart';
import '../../../shared/domain/env_chart_data.dart';
import '../../../shared/domain/env_day.dart';
import '../../../shared/domain/env_extremes.dart';
import '../../../shared/domain/week_range.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import 'home_control_providers.dart';

/// 온습도 상세(`/env-detail`) 프로바이더 (계획서 2026-09-02 T3).
///
/// 하루 경계는 **자정**([EnvDay], B.4 결정)이다 — 홈 24h 차트의
/// [chartWindowProvider](6시간 전진 프레임)·어젯밤 리포트(07:00 경계)와
/// 다른 개념이니 혼용하지 말 것.

/// 상세 화면이 보고 있는 날. 페이저가 previous/next로 교체한다.
final envDetailDayProvider =
    StateProvider.autoDispose<EnvDay>((ref) => EnvDay.of(DateTime.now()));

/// 상세 화면이 보고 있는 주 (월요일 시작).
final envDetailWeekProvider = StateProvider.autoDispose<WeekRange>(
    (ref) => WeekRange.containing(DateTime.now()));

/// 보고 있는 날의 30분 버킷. 기기가 없으면 빈 목록.
final envDayBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  // watch는 await 앞에서 (home_set_providers.dart 규칙).
  final repository = ref.watch(supabaseModuleControlRepositoryProvider);
  final day = ref.watch(envDetailDayProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  // 오늘은 아직 안 지난 시간을 물어볼 이유가 없다 — 끝을 now로 자른다.
  final now = DateTime.now();
  final to = day.end.isBefore(now) ? day.end : now;
  return repository.telemetryHistory(deviceId, day.start, to: to);
});

/// 보고 있는 날의 차트 데이터. x = 0(자정)~1(다음 자정) — 오늘의 미도래
/// 구간은 점이 없어 빈 영역으로 남는다(§A.5).
final envDayChartDataProvider =
    FutureProvider.autoDispose<EnvChartData>((ref) async {
  final day = ref.watch(envDetailDayProvider);
  final buckets = await ref.watch(envDayBucketsProvider.future);
  return EnvChartData.from(buckets, from: day.start, to: day.end);
});

/// 보고 있는 날의 최고/최저. **차트와 같은 창**을 쓴다(어긋나면 요약이
/// 그래프를 설명하지 못한다 — chartExtremesProvider와 같은 교훈).
final envDayExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  return EnvExtremes.from(await ref.watch(envDayBucketsProvider.future));
});

/// 보고 있는 날의 기기 동작 마커 (차트 위 아이콘 행).
final envDayMarkersProvider =
    FutureProvider.autoDispose<List<ActuatorMarker>>((ref) async {
  final day = ref.watch(envDetailDayProvider);
  final client = ref.watch(supabaseClientProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  return fetchActuatorMarkers(client, deviceId, from: day.start, to: day.end);
});

/// 보고 있는 날의 사육장 제어 기록 (시간 오름차순).
///
/// 마커와 **같은 rows**([fetchCommandRows])에 그 날 버킷을 붙여 시점
/// 온습도·델타를 계산한다.
final envDayControlLogProvider =
    FutureProvider.autoDispose<List<ControlLogEntry>>((ref) async {
  final day = ref.watch(envDetailDayProvider);
  final client = ref.watch(supabaseClientProvider);
  // watch는 await 앞에서 — await 뒤의 watch는 dispose(날짜 페이저 연타·화면
  // 이탈) 후 continuation이 죽은 element에 걸려 StateError가 되고, 화면은
  // 기록이 있는 날인데 "기록 없음"을 그린다(리뷰 2026-09-03). 먼저 잡아두면
  // commands·버킷 조회가 병렬로도 돈다.
  final bucketsFuture = ref.watch(envDayBucketsProvider.future);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final rows = await fetchCommandRows(
    client,
    deviceId,
    from: day.start,
    to: day.end,
  );
  final buckets = await bucketsFuture;
  return buildControlLog(commandRows: rows, buckets: buckets);
});

/// 보고 있는 주의 요일별 온/습 min/max — 각각 **항상 7칸 고정**
/// (데이터 없는 요일은 min/max null). 기기가 없어도 7칸 빈 축을 준다.
final envWeekRowsProvider = FutureProvider.autoDispose<
    ({List<DayMinMax> temp, List<DayMinMax> humid})>((ref) async {
  final repository = ref.watch(supabaseModuleControlRepositoryProvider);
  final week = ref.watch(envDetailWeekProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  var buckets = const <TelemetryBucket>[];
  if (deviceId != null) {
    final now = DateTime.now();
    final to = week.end.isBefore(now) ? week.end : now;
    buckets = await repository.telemetryHistory(deviceId, week.start, to: to);
  }
  return (
    temp: weekTempRanges(buckets, week),
    humid: weekHumidRanges(buckets, week),
  );
});

/// 홈 요약 카드의 오늘(자정~지금) 최고/최저 (§A.4 ③, B.4 결정).
///
/// 홈 24h 차트 창과 **다른 구간**이다 — 카드 문구가 "오늘"이라 자정 경계다.
final homeTodayExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  final repository = ref.watch(supabaseModuleControlRepositoryProvider);
  final day = ref.watch(_todayProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) {
    return const EnvExtremes(
      tempMin: null,
      tempMax: null,
      humidMin: null,
      humidMax: null,
    );
  }
  final buckets =
      await repository.telemetryHistory(deviceId, day.start, to: DateTime.now());
  return EnvExtremes.from(buckets);
});

/// "오늘"의 자정 경계 — **자정을 넘기면 스스로 무효화**한다.
///
/// 홈 [EnvSummaryCard]가 상시 watch라 autoDispose가 발동하지 않아, 타이머
/// 없이는 자정 이후에도 어제 창의 최고/최저가 남는다(리뷰 2026-09-03).
final _todayProvider = Provider.autoDispose<EnvDay>((ref) {
  final now = DateTime.now();
  final day = EnvDay.of(now);
  final timer = Timer(
    day.end.difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return day;
});
