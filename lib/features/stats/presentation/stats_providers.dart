import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/chart_window.dart';
import '../../../shared/domain/env_chart_data.dart';
import '../../../shared/domain/env_extremes.dart';
import '../../home/presentation/home_control_providers.dart';
import '../domain/stats_metric.dart';
import '../domain/stats_period.dart';
import 'weekly_providers.dart';

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

/// 선택된 기간의 차트 창. **기간 → 소스 매핑은 여기 한 곳뿐이다** —
/// 화면마다 `weekly ? A : B` 삼항을 두면 월간을 붙일 때 전부 찾아다녀야 한다.
final statsWindowProvider = Provider.autoDispose<ChartWindow>((ref) =>
    ref.watch(statsPeriodProvider) == StatsPeriod.weekly
        ? ref.watch(weeklyWindowProvider)
        : ref.watch(chartWindowProvider));

/// 선택된 기간의 차트 데이터. [statsWindowProvider]와 같은 매핑 규칙.
///
/// 원천의 AsyncValue를 **그대로 넘긴다**(FutureProvider로 다시 감싸지 않는다)
/// — 로딩·에러 상태가 한 겹 늦게 도착할 이유가 없다. 대신 무효화는 파생이
/// 아니라 원천에 해야 하므로 [invalidateStatsChartData]를 쓸 것.
final statsChartDataProvider =
    Provider.autoDispose<AsyncValue<EnvChartData>>((ref) =>
        ref.watch(statsPeriodProvider) == StatsPeriod.weekly
            ? ref.watch(weeklyChartDataProvider)
            : ref.watch(envChartDataProvider));

/// 선택된 기간의 최고/최저. [statsWindowProvider]와 같은 매핑 규칙.
final statsExtremesProvider =
    Provider.autoDispose<AsyncValue<EnvExtremes>>((ref) =>
        ref.watch(statsPeriodProvider) == StatsPeriod.weekly
            ? ref.watch(weeklyExtremesProvider)
            : ref.watch(chartExtremesProvider));

/// 로드 실패 재시도. 파생([statsChartDataProvider])을 무효화해도 원천은 다시
/// 돌지 않으므로, 현재 기간의 **원천을 짚어서** 무효화한다.
void invalidateStatsChartData(WidgetRef ref) {
  ref.invalidate(ref.read(statsPeriodProvider) == StatsPeriod.weekly
      ? weeklyChartDataProvider
      : envChartDataProvider);
}

/// 스크러버 위치(0~1). null이면 스크럽 중이 아니다.
///
/// 차트와 요약 바가 이 값 하나로 이어진다 — Figma 변형 B에서 스크럽을 시작하면
/// 상단 요약이 **그 시점의 값으로 바뀐다**(`docs/figma-final-design-transcript.md`
/// §3.1 "스크러버 툴팁"). 두 위젯이 형제라 상태를 위로 올리는 대신 provider로 잇는다.
final statsScrubProvider = StateProvider.autoDispose<double?>((ref) => null);
