import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../home/domain/actuator_marker.dart';
import '../../home/domain/env_extremes.dart';
import '../../home/presentation/home_control_providers.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../domain/stats_chart_data.dart';
import '../domain/stats_metric.dart';
import '../domain/stats_period.dart';
import '../domain/stats_window.dart';

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

/// 통계 탭 차트의 표시 창([StatsWindow]).
///
/// 화면이 살아 있는 동안 고정이다 — 1초마다 다시 잡으면 눈금과 회색 밴드가
/// 미세하게 떨려서 읽을 수 없다. 6시간마다 전진하는 프레임이라 화면을 다시
/// 열면 알아서 최신으로 잡힌다.
final statsWindowProvider =
    Provider.autoDispose<StatsWindow>((ref) => StatsWindow.of(DateTime.now()));

/// 표시 창에 해당하는 온습도 버킷.
///
/// **홈 미니 차트([chartBucketsProvider])와 구간이 다르다.** 홈은 전날 19:00
/// 고정이지만 통계 창은 6시간마다 전진해서 최대 24시간 전까지 거슬러 간다.
/// 홈 구간을 그대로 쓰면 창 왼쪽이 최대 3시간 비어 선이 잘린다.
///
/// 조회 끝은 창 끝(미래)이 아니라 **지금**이다 — 없는 시간을 물어볼 이유가 없다.
final statsBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final w = ref.watch(statsWindowProvider);
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, w.start, to: w.now);
});

/// 차트가 보여주는 구간의 최고/최저.
///
/// **차트와 같은 창을 쓴다.** 요약 바의 숫자는 바로 아래 그래프를 설명하는
/// 값이라, 다른 창을 쓰면 서로 어긋난다 — 홈의 당일(07:00~) 창
/// ([todayExtremesProvider])을 쓰던 동안, 그래프에는 27~32℃ 곡선이 그려져
/// 있는데 최고/최저는 `--`로 뜨는 화면이 실기기에서 나왔다.
final statsExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  return EnvExtremes.from(await ref.watch(statsBucketsProvider.future));
});

/// 표시 창의 기기 동작 마커(Figma §3.1 "동작 마커").
final statsActuatorMarkersProvider =
    FutureProvider.autoDispose<List<ActuatorMarker>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final w = ref.watch(statsWindowProvider);
  return fetchActuatorMarkers(
    ref.watch(supabaseClientProvider),
    deviceId,
    from: w.start,
    to: w.now,
  );
});

/// 통계 탭 24시간 차트 데이터.
///
/// x 정규화 기준은 **창 끝([StatsWindow.end], 미래)**이다. 지금까지로 잡으면
/// 선이 오른쪽 벽에 붙어 회색 밴드가 들어갈 자리가 없어진다.
final statsChartDataProvider =
    FutureProvider.autoDispose<StatsChartData>((ref) async {
  final buckets = await ref.watch(statsBucketsProvider.future);
  final w = ref.watch(statsWindowProvider);
  return StatsChartData.from(buckets, from: w.start, to: w.end);
});

/// 스크러버 위치(0~1). null이면 스크럽 중이 아니다.
///
/// 차트와 요약 바가 이 값 하나로 이어진다 — Figma 변형 B에서 스크럽을 시작하면
/// 상단 요약이 **그 시점의 값으로 바뀐다**(`docs/figma-final-design-transcript.md`
/// §3.1 "스크러버 툴팁"). 두 위젯이 형제라 상태를 위로 올리는 대신 provider로 잇는다.
final statsScrubProvider = StateProvider.autoDispose<double?>((ref) => null);
