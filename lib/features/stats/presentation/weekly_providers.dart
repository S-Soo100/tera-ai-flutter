import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/home_control_providers.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import '../../../shared/domain/chart_window.dart';
import '../../../shared/domain/env_chart_data.dart';
import '../../../shared/domain/env_extremes.dart';
import '../domain/daily_rollup.dart';

/// 주간 창(최근 7일). 화면이 살아 있는 동안 고정한다 — 일간 창과 같은 이유로,
/// 매 초 다시 잡으면 눈금과 회색 밴드가 미세하게 떨린다.
final weeklyWindowProvider = Provider.autoDispose<ChartWindow>(
    (ref) => ChartWindow.weekly(DateTime.now()));

/// 주간 창의 30분 버킷 원본. 7일 × 48 = 최대 336행.
///
/// 조회는 일간과 같은 [fetchChartBuckets] 한 벌이다 — 여기는 창 공급과
/// 하루 접기([rollupByDay])만 맡는다. 끝은 창 끝(직전 07:00)이다: now까지
/// 당기면 진행 중인 오늘 몫이 딸려와 창 밖 데이터를 rollup이 도로 버린다.
final _weeklyRawBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) {
  final w = ref.watch(weeklyWindowProvider);
  return fetchChartBuckets(ref, w, to: w.end);
});

/// 하루 단위로 접은 7칸. 주간 차트와 분포 바가 **같은 값**을 쓴다 —
/// 두 번 집계하면 같은 날의 최고 온도가 화면마다 달라진다.
final weeklyDailyBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  // watch는 반드시 await **앞에서** 한다(home_set_providers.dart 규칙) —
  // await 뒤의 watch는 dispose 후 continuation이 죽은 element에 걸려
  // 창 전진이 반영되지 않는다.
  final w = ref.watch(weeklyWindowProvider);
  final raw = await ref.watch(_weeklyRawBucketsProvider.future);
  return rollupByDay(raw, window: w);
});

/// 주간 차트용 데이터. 선은 **일 평균**이고, 그 날의 변동폭은 분포(§4.3.6)가 맡는다.
final weeklyChartDataProvider =
    FutureProvider.autoDispose<EnvChartData>((ref) async {
  // watch를 await 앞으로 — 위 provider와 같은 이유.
  final w = ref.watch(weeklyWindowProvider);
  final days = await ref.watch(weeklyDailyBucketsProvider.future);
  return EnvChartData.from(days, from: w.start, to: w.end);
});

/// 주간 최고/최저. 일 평균이 아니라 **그 주 전체의 극값**이다 —
/// 평균의 극값을 쓰면 실제로 겪은 최고 온도가 30분 평균에 눌려 낮게 보인다.
final weeklyExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  return EnvExtremes.from(await ref.watch(weeklyDailyBucketsProvider.future));
});
