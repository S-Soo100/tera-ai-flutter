import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/day_window.dart';
import '../../home/presentation/home_control_providers.dart';
import '../domain/stats_chart_data.dart';
import '../domain/stats_metric.dart';
import '../domain/stats_period.dart';

/// 선택된 조회 기간(§4.3.1).
final statsPeriodProvider =
    StateProvider<StatsPeriod>((ref) => StatsPeriod.daily);

/// 차트에 겹쳐 그릴 지표(§4.3.2, 다중 선택).
///
/// 기본값은 온·습도 둘 다 — 이 둘의 **관계**를 읽는 게 이 화면의 목적이라
/// 하나만 켜고 시작하면 요점을 놓친다.
final statsMetricsProvider = StateProvider<Set<StatsMetric>>(
  (ref) => {StatsMetric.temperature, StatsMetric.humidity},
);

/// 통계 탭 24시간 차트 데이터.
///
/// **홈의 미니 차트와 같은 구간**([DayWindow.chartRange] = 전날 19:00~현재)을
/// 쓴다. PRD §3.4가 홈 차트를 터치하면 통계 탭으로 보내는데, 그 두 화면이
/// 서로 다른 구간을 보여주면 "방금 본 그래프"가 아니게 된다.
///
/// 버킷·기기 조회는 홈 provider를 그대로 재사용한다 — 같은 질의를 두 번
/// 만들지 않기 위함이다.
final statsChartDataProvider =
    FutureProvider.autoDispose<StatsChartData>((ref) async {
  final buckets = await ref.watch(chartBucketsProvider.future);
  final r = DayWindow.chartRange(DateTime.now());
  return StatsChartData.from(buckets, from: r.start, to: r.end);
});
