import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 스크러버 위치(0~1). null이면 스크럽 중이 아니다.
///
/// 차트와 요약 바가 이 값 하나로 이어진다 — Figma 변형 B에서 스크럽을 시작하면
/// 상단 요약이 **그 시점의 값으로 바뀐다**(`docs/figma-final-design-transcript.md`
/// §3.1 "스크러버 툴팁"). 두 위젯이 형제라 상태를 위로 올리는 대신 provider로 잇는다.
final statsScrubProvider = StateProvider.autoDispose<double?>((ref) => null);
