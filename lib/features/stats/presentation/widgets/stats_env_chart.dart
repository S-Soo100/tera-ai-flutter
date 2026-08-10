import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/actuator_marker.dart';
import '../../domain/axis_bounds.dart';
import '../../domain/stats_chart_data.dart';
import '../../domain/stats_metric.dart';
import '../../domain/stats_window.dart';
import '../stats_providers.dart';

/// Figma `온습도 그래프 - 24시` 본체
/// (`docs/figma-final-design-transcript.md` §3.1).
///
/// 좌축 = 온도, 우축 = 습도, X축 = 6시간 간격 시각.
/// 두 지표는 단위가 달라 [StatsChartData]에서 **각자 0~1로 정규화**해 온다.
/// 그래서 차트의 Y는 항상 0~1이고, 사람이 읽는 눈금은 좌우 라벨 컬럼이 담당한다.
///
/// 오버레이 3종도 여기서 그린다 — 동작 마커(위), 미도래 밴드(플롯 안),
/// 스크러버(터치).
class StatsEnvChart extends ConsumerWidget {
  const StatsEnvChart({
    super.key,
    required this.data,
    required this.window,
    this.markers = const [],
    this.metrics = const {StatsMetric.temperature, StatsMetric.humidity},
  });

  final StatsChartData data;

  /// 표시 창. 눈금 위치와 회색 밴드 시작점이 여기서 나온다.
  final StatsWindow window;

  /// 기기 동작 마커. 비어 있으면 마커 행이 자리를 차지하지 않는다.
  final List<ActuatorMarker> markers;

  /// 그릴 지표(§4.3.2 필터). 꺼진 지표는 **선도 축 라벨도 함께 사라진다** —
  /// 선만 지우면 읽을 값이 없는 눈금만 남는다.
  final Set<StatsMetric> metrics;

  static const chartKey = Key('stats_env_chart');
  static const markerRowKey = Key('stats_marker_row');

  /// 플롯 영역 높이. Figma의 Y축 라벨 컬럼(104px, 6단)에 맞춘 값.
  static const double _plotHeight = 180;

  /// 이 위젯을 감싸는 좌우 여백. 화면이 주는 값과 **같아야** 한다 —
  /// 요약 바가 스크러버를 따라갈 때 이 값으로 플롯 좌표를 되짚기 때문이다.
  static const double outerPadding = AppStyles.spacing12;

  /// 화면 왼쪽 끝에서 플롯이 시작하는 거리.
  static const double plotInset =
      outerPadding + _AxisLabels.width + AppStyles.spacing4;

  bool get _temp => metrics.contains(StatsMetric.temperature);
  bool get _humid => metrics.contains(StatsMetric.humidity);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: onVariant);

    // 좌우 라벨 컬럼(폭 + 여백)만큼 안쪽으로 들어간 자리가 실제 플롯이다.
    // 마커·시간축이 선과 같은 x를 가리키려면 같은 만큼 밀어야 한다.
    const inset = _AxisLabels.width + AppStyles.spacing4;

    return Column(
      key: chartKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (markers.isNotEmpty)
          Padding(
            key: markerRowKey,
            padding: const EdgeInsets.symmetric(horizontal: inset),
            child: _MarkerRow(markers: markers, window: window),
          ),
        SizedBox(
          height: _plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AxisLabels(
                axis: _temp ? data.tempAxis : null,
                format: (v) => 'stats_axis_temp'.tr(
                  namedArgs: {'v': v.toStringAsFixed(0)},
                ),
                style: labelStyle,
                alignment: TextAlign.right,
              ),
              const SizedBox(width: AppStyles.spacing4),
              Expanded(
                child: _Plot(data: data, window: window, metrics: metrics),
              ),
              const SizedBox(width: AppStyles.spacing4),
              _AxisLabels(
                axis: _humid ? data.humidAxis : null,
                format: (v) => 'stats_axis_humid'.tr(
                  namedArgs: {'v': v.toStringAsFixed(0)},
                ),
                style: labelStyle,
                alignment: TextAlign.left,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppStyles.spacing4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: inset),
          child: _TimeAxis(window: window, style: labelStyle),
        ),
      ],
    );
  }
}

/// Y축 라벨 컬럼. 위가 max, 아래가 min이며 **균등 배치**한다.
///
/// 좌우 눈금 개수가 달라도 괜찮다 — 각 축이 자기 범위를 선형으로 나눠 갖기
/// 때문에 균등 배치가 곧 올바른 위치다. Figma도 같은 방식(텍스트 6개 컬럼)이다.
class _AxisLabels extends StatelessWidget {
  const _AxisLabels({
    required this.axis,
    required this.format,
    required this.style,
    required this.alignment,
  });

  final AxisBounds? axis;
  final String Function(double) format;
  final TextStyle? style;
  final TextAlign alignment;

  /// 라벨 컬럼 폭. **비어 있어도 자리를 지킨다** — 지표를 끌 때 폭이 줄면
  /// 플롯이 옆으로 밀리고, 고정값을 쓰는 [_TimeAxis]의 눈금이 어긋난다.
  static const double width = 34;

  @override
  Widget build(BuildContext context) {
    if (axis == null) return const SizedBox(width: width);
    final ticks = axis!.ticks.reversed.toList(); // 위 → 아래

    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in ticks)
            Text(
              format(t),
              textAlign: alignment,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
        ],
      ),
    );
  }
}

class _Plot extends ConsumerWidget {
  const _Plot({required this.data, required this.window, required this.metrics});

  final StatsChartData data;
  final StatsWindow window;
  final Set<StatsMetric> metrics;

  /// 실제로 그려지는 선들. **툴팁이 barIndex로 되짚어야 하므로 목록을 한 번만
  /// 만든다** — 조건을 두 곳에 복붙하면 필터를 켤 때마다 툴팁이 엉뚱한 축의
  /// 값을 읽는다.
  List<({List<({double x, double y})> pts, AxisBounds? axis, bool isTemp})>
      get _series => [
            if (metrics.contains(StatsMetric.temperature) &&
                data.tempPoints.length > 1)
              (pts: data.tempPoints, axis: data.tempAxis, isTemp: true),
            if (metrics.contains(StatsMetric.humidity) &&
                data.humidPoints.length > 1)
              (pts: data.humidPoints, axis: data.humidAxis, isTemp: false),
          ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final grid = theme.dividerColor;
    final scrubLine = theme.colorScheme.onSurface;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        // 눈금 라벨은 좌우 컬럼과 하단 행이 직접 그린다. fl_chart의 타이틀을
        // 함께 켜면 같은 값이 두 번 나온다.
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: grid),
            bottom: BorderSide(color: grid),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          // 정규화 축이라 0.2 간격이면 가로 5칸 — 눈금 개수와 무관하게 일정하다.
          horizontalInterval: 0.2,
          verticalInterval: 0.25,
          getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 0.5),
          getDrawingVerticalLine: (_) => FlLine(color: grid, strokeWidth: 0.5),
        ),
        // 미도래 구간(= 아직 안 지난 시간)을 회색으로 덮는다. 선 **아래**에
        // 깔리므로 곡선을 가리지 않는다.
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            if (window.elapsed < 1)
              VerticalRangeAnnotation(
                x1: window.elapsed,
                x2: 1,
                color: AppTheme.chartFutureBand(theme.brightness),
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          // 기본 말풍선은 끈다 — 값은 상단 요약 바가 Figma 배치대로 보여준다.
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItems: (spots) => List.filled(spots.length, null),
          ),
          // Figma "스크러버 점": 세로선 + 선 위 흰 점(4×4, 테두리 `#1e1e1e`).
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: scrubLine, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (spot, pct, barData, index) =>
                      FlDotCirclePainter(
                    radius: 2,
                    color: theme.colorScheme.surface,
                    strokeColor: scrubLine,
                    strokeWidth: 1,
                  ),
                ),
              ),
          ],
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            // 손을 떼면 요약 바를 원래 값으로 되돌린다.
            if (!event.isInterestedForInteractions ||
                spots == null ||
                spots.isEmpty) {
              ref.read(statsScrubProvider.notifier).state = null;
              return;
            }
            final x = spots.first.x;
            ref.read(statsScrubProvider.notifier).state = data.snap(x) ?? x;
          },
        ),
        lineBarsData: [
          for (final s in _series)
            _bar(
              s.pts,
              s.isTemp ? AppTheme.chartTemperature : AppTheme.chartHumidity,
            ),
        ],
      ),
    );
  }

  LineChartBarData _bar(List<({double x, double y})> pts, Color color) {
    return LineChartBarData(
      spots: [for (final p in pts) FlSpot(p.x, p.y)],
      color: color,
      barWidth: 2,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
    );
  }
}

/// 기기 동작 마커 행 (Figma §3.1 "동작 마커").
///
/// 14×14 칩에 아이콘을 담아 플롯 **위쪽 바깥**에 얹는다. 플롯 안에 넣으면
/// 곡선과 겹쳐 둘 다 못 읽는다.
class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.markers, required this.window});

  final List<ActuatorMarker> markers;
  final StatsWindow window;

  static const double chipSize = 14;

  static const _icon = {
    MarkerKind.mist: Icons.shower,
    MarkerKind.fan: Icons.mode_fan_off,
    MarkerKind.heater: Icons.local_fire_department,
    MarkerKind.led: Icons.lightbulb,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 마커는 "언제 돌았나"만 알려주면 된다. 기기마다 색을 주면 온·습도 선과
    // 색이 경쟁해 정작 읽어야 할 곡선이 묻힌다 — 무채색으로 억제한다.
    final fg = theme.colorScheme.onSurfaceVariant;
    final bg = AppTheme.chartMarkerChip(theme.brightness);

    return SizedBox(
      height: chipSize + AppStyles.spacing4,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            for (final m in markers)
              if (m.positionIn(start: window.start, end: window.end)
                  case final p?)
                Positioned(
                  // 양 끝에서 칩이 잘리지 않게 안쪽으로 붙인다.
                  left: (p * c.maxWidth - chipSize / 2)
                      .clamp(0.0, (c.maxWidth - chipSize).clamp(0.0, double.infinity)),
                  top: 0,
                  child: Container(
                    width: chipSize,
                    height: chipSize,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(_icon[m.kind], size: 10, color: fg),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// X축 시각 라벨. 눈금은 [StatsWindow]가 정한다 — 창 시작부터 6시간 간격 4개.
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.window, required this.style});

  final StatsWindow window;
  final TextStyle? style;

  static const double _labelWidth = 52;

  @override
  Widget build(BuildContext context) {
    final ticks = window.ticks;
    if (ticks.isEmpty) return const SizedBox(height: 14);

    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            for (final t in ticks)
              Positioned(
                left: (t.position * c.maxWidth - _labelWidth / 2).clamp(
                  0.0,
                  (c.maxWidth - _labelWidth).clamp(0.0, double.infinity),
                ),
                child: SizedBox(
                  width: _labelWidth,
                  child: Text(
                    (t.isAm ? 'home_chart_time_am' : 'home_chart_time_pm')
                        .tr(namedArgs: {'h': '${t.hour12}'}),
                    textAlign: TextAlign.center,
                    style: style,
                    maxLines: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
