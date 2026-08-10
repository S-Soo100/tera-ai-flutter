import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../home/domain/actuator_marker.dart';
import '../../domain/axis_bounds.dart';
import '../../domain/stats_chart_data.dart';
import '../../domain/stats_metric.dart';
import '../../domain/stats_window.dart';
import '../stats_providers.dart';

/// Figma `온습도 그래프 - 24시` 본체
/// (`docs/figma-final-design-transcript.md` §3.1).
///
/// **치수는 Figma 393pt 프레임에서 벡터 좌표를 그대로 옮긴 값이다.** 눈대중으로
/// 맞추면 아래 세 구간이 서로 어긋난다 — 격자선이 도는 범위, 마커가 앉는 여백,
/// 세로선이 뻗는 길이가 전부 다르기 때문이다.
///
/// ```
/// ┌─ 플롯 박스 (113.73) ──────────────────────────┐
/// │ ▣ ▣  ▣          ← 동작 마커 (0~14, headroom)   │
/// │────────────────────────────  ← 격자선 1 (16.73)│
/// │ ⋮ 18pt 간격으로 6줄, 각 줄이 Y축 라벨 중앙       │
/// │────────────────────────────  ← 격자선 6 (106.73)│
/// │                              ← footroom 7      │
/// └────────────────────────────────────────────────┘
///     ↑ 세로선은 박스 전체 높이를 관통한다
/// ```
///
/// 좌축 = 온도, 우축 = 습도. 두 지표는 단위가 달라 [StatsChartData]에서 **각자
/// 0~1로 정규화**해 온다. 사람이 읽는 눈금은 좌우 라벨 컬럼이 담당한다.
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

  /// 기기 동작 마커. 그 시각에 실제로 돌았다는 기록이다.
  final List<ActuatorMarker> markers;

  /// 그릴 지표(§4.3.2 필터). 꺼진 지표는 **선도 축 라벨도 함께 사라진다** —
  /// 선만 지우면 읽을 값이 없는 눈금만 남는다.
  final Set<StatsMetric> metrics;

  static const chartKey = Key('stats_env_chart');
  static const markerRowKey = Key('stats_marker_row');

  // ── 가로 (Figma: 20 | 20 | 3 | 300 | 4 | 26 | 20 = 393) ──

  /// 화면 좌우 여백. 요약 바도 같은 값을 써야 스크러버가 선과 맞는다.
  static const double outerPadding = 20;

  /// 좌 축(온도) 라벨 컬럼 폭. `45°`가 들어가는 최소 폭이다.
  static const double tempLabelWidth = 20;
  static const double tempGap = 3;

  /// 우 축(습도) 라벨 컬럼 폭. `%`가 붙어 좌축보다 넓다.
  static const double humidLabelWidth = 26;
  static const double humidGap = 4;

  /// 화면 왼쪽 끝에서 플롯이 시작하는 거리(= Figma 43).
  static const double plotInset = outerPadding + tempLabelWidth + tempGap;

  /// 화면 오른쪽 끝에서 플롯이 끝나는 거리.
  static const double plotInsetRight = outerPadding + humidLabelWidth + humidGap;

  // ── 세로 ──

  /// Y축 라벨 한 줄 높이(12pt 텍스트).
  static const double labelHeight = 14;

  /// 격자선 간격.
  static const double rowStep = 18;

  /// 격자선(= Y축 눈금) 개수.
  static const int rowCount = 6;

  /// 첫 격자선까지의 윗여백. **동작 마커가 앉는 자리**라 비워둔 것이지
  /// 그냥 여백이 아니다.
  static const double headroom = 16.73;

  /// 마지막 격자선 아래 여백. 세로선만 여기까지 더 내려온다.
  static const double footroom = 7;

  /// 첫 격자선 ~ 마지막 격자선. 정규화 0~1이 이 구간에 대응한다.
  static const double gridSpan = rowStep * (rowCount - 1);

  /// 플롯 박스 전체 높이(Figma 113.73).
  static const double plotHeight = headroom + gridSpan + footroom;

  /// 동작 마커 칩 한 변.
  static const double markerChip = 14;

  /// 라벨 컬럼 시작 오프셋 — 라벨 **중앙**이 격자선에 오게 맞춘다.
  static const double labelColumnTop = headroom - labelHeight / 2;

  bool get _temp => metrics.contains(StatsMetric.temperature);
  bool get _humid => metrics.contains(StatsMetric.humidity);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      key: chartKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AxisLabels(
                axis: _temp ? data.tempAxis : null,
                width: tempLabelWidth,
                alignment: TextAlign.right,
                format: (v) => 'stats_axis_temp'
                    .tr(namedArgs: {'v': v.toStringAsFixed(0)}),
                style: style,
              ),
              const SizedBox(width: tempGap),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _Plot(
                          data: data, window: window, metrics: metrics),
                    ),
                    // 마커는 격자선 위 여백에 앉는다 — 플롯 안에 넣으면 곡선과
                    // 겹쳐 둘 다 못 읽는다.
                    if (markers.isNotEmpty)
                      Positioned(
                        key: markerRowKey,
                        top: 0,
                        left: 0,
                        right: 0,
                        height: markerChip,
                        child: _MarkerRow(markers: markers, window: window),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: humidGap),
              _AxisLabels(
                axis: _humid ? data.humidAxis : null,
                width: humidLabelWidth,
                alignment: TextAlign.left,
                format: (v) => 'stats_axis_humid'
                    .tr(namedArgs: {'v': v.toStringAsFixed(0)}),
                style: style,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: tempLabelWidth + tempGap,
            right: humidLabelWidth + humidGap,
          ),
          child: _TimeAxis(window: window, style: style),
        ),
      ],
    );
  }
}

/// Y축 라벨 컬럼.
///
/// 라벨 **중앙**이 격자선에 오도록 위치를 직접 잡는다. `spaceBetween`으로
/// 흘리면 맨 위·아래 라벨만 반 칸씩 밀려 격자선과 어긋난다.
class _AxisLabels extends StatelessWidget {
  const _AxisLabels({
    required this.axis,
    required this.width,
    required this.alignment,
    required this.format,
    required this.style,
  });

  final AxisBounds? axis;
  final double width;
  final TextAlign alignment;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    // 지표를 꺼도 **폭은 지킨다** — 줄어들면 플롯이 옆으로 밀려 시간축 눈금이
    // 선과 어긋난다.
    if (axis == null) return SizedBox(width: width);
    final ticks = axis!.ticks.reversed.toList(); // 위 → 아래

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: StatsEnvChart.labelColumnTop),
          for (var i = 0; i < ticks.length; i++) ...[
            if (i > 0)
              const SizedBox(
                  height: StatsEnvChart.rowStep - StatsEnvChart.labelHeight),
            SizedBox(
              height: StatsEnvChart.labelHeight,
              child: Text(
                format(ticks[i]),
                textAlign: alignment,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 격자선 + 미도래 밴드. **fl_chart에 맡기지 않고 직접 그린다.**
///
/// 세 요소가 서로 다른 세로 범위를 쓰기 때문이다 — 가로선은 첫~마지막 격자선
/// 구간(90), 세로선은 박스 전체(113.73), 밴드는 박스 위쪽부터 마지막 격자선까지
/// (106.73). 차트 라이브러리의 격자는 이 셋을 한 범위로만 그린다.
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.elapsed,
    required this.line,
    required this.band,
  });

  /// 흘러간 비율. 여기서부터 오른쪽 끝까지가 회색 밴드다.
  final double elapsed;
  final Color line;
  final Color band;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 1
      ..isAntiAlias = false;

    // 가로: Y축 눈금마다 한 줄.
    for (var i = 0; i < StatsEnvChart.rowCount; i++) {
      final y = StatsEnvChart.headroom + i * StatsEnvChart.rowStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
    }

    // 세로: 6시간 눈금 4개 + 오른쪽 끝. 박스 전체를 관통한다.
    for (var i = 0; i <= 4; i++) {
      final x = (size.width * i / 4).clamp(0.0, size.width - 0.5);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
    }

    // 밴드는 격자선 **위에** 덮는다(Figma 순서). 아래에 깔면 격자가 비쳐
    // "데이터가 있는데 흐린 것"처럼 보인다.
    if (elapsed < 1) {
      canvas.drawRect(
        Rect.fromLTRB(
          size.width * elapsed,
          0,
          size.width,
          StatsEnvChart.headroom + StatsEnvChart.gridSpan,
        ),
        Paint()..color = band,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.elapsed != elapsed || old.line != line || old.band != band;
}

class _Plot extends ConsumerWidget {
  const _Plot({required this.data, required this.window, required this.metrics});

  final StatsChartData data;
  final StatsWindow window;
  final Set<StatsMetric> metrics;

  /// 정규화 0~1을 격자선 구간에 앉히기 위한 여유. 위로는 마커 자리만큼,
  /// 아래로는 footroom만큼 데이터 범위를 넓혀 잡는다.
  static const double _minY = -StatsEnvChart.footroom / StatsEnvChart.gridSpan;
  static const double _maxY = 1 + StatsEnvChart.headroom / StatsEnvChart.gridSpan;

  /// 실제로 그려지는 선들. **툴팁이 barIndex로 되짚어야 하므로 목록을 한 번만
  /// 만든다** — 조건을 두 곳에 복붙하면 필터를 켤 때마다 엉뚱한 축을 읽는다.
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
    final scrubLine = theme.colorScheme.onSurface;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(
              elapsed: window.elapsed,
              line: AppTheme.chartGridLine(theme.brightness),
              band: AppTheme.chartFutureBand(theme.brightness),
            ),
          ),
        ),
        Positioned.fill(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 1,
              minY: _minY,
              maxY: _maxY,
              // 격자·테두리·눈금 라벨은 전부 이 위젯이 직접 그린다.
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
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
                  ref.read(statsScrubProvider.notifier).state =
                      data.snap(x) ?? x;
                },
              ),
              lineBarsData: [
                for (final s in _series)
                  _bar(
                    s.pts,
                    s.isTemp
                        ? AppTheme.chartTemperature
                        : AppTheme.chartHumidity,
                  ),
              ],
            ),
          ),
        ),
      ],
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

/// 기기 동작 마커 (Figma §3.1 "동작 마커").
///
/// **장식이 아니라 기록이다** — 칩이 있다는 건 그 시각에 환기나 분무가 *실제로
/// 실행됐다*는 뜻이다(`commands`의 `status='acked'`만 온다). 아이콘만 떠 있으면
/// 그 뜻이 읽히지 않으므로 **눌러서 확인할 수 있게** 한다. 화면을 읽어주는
/// 보조기술에도 같은 문장이 전달된다.
class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.markers, required this.window});

  final List<ActuatorMarker> markers;
  final StatsWindow window;

  /// Figma가 준 SVG는 분무·팬 둘뿐이다. 히터·LED는 아직 그림이 없어 Material
  /// 아이콘으로 받친다 — 자리를 비우면 동작한 기록이 사라진다.
  static const _svg = {
    MarkerKind.mist: FigmaIcons.shower,
    MarkerKind.fan: FigmaIcons.modeFan,
  };

  static const _fallbackIcon = {
    MarkerKind.heater: Icons.local_fire_department,
    MarkerKind.led: Icons.lightbulb,
  };

  static const _labelKey = {
    MarkerKind.mist: 'stats_marker_mist',
    MarkerKind.fan: 'stats_marker_fan',
    MarkerKind.heater: 'stats_marker_heater',
    MarkerKind.led: 'stats_marker_led',
  };

  Widget _glyph(MarkerKind kind, Color color) {
    final name = _svg[kind];
    if (name != null) {
      return FigmaIcon.tinted(name,
          color: color, size: StatsEnvChart.markerChip);
    }
    return Icon(_fallbackIcon[kind], size: 10, color: color);
  }

  String _label(ActuatorMarker m) {
    final isAm = m.at.hour < 12;
    final h12 = m.at.hour % 12 == 0 ? 12 : m.at.hour % 12;
    final time = (isAm ? 'stats_scrub_time_am' : 'stats_scrub_time_pm').tr(
      namedArgs: {
        'h': '$h12',
        'm': m.at.minute.toString().padLeft(2, '0'),
      },
    );
    return 'stats_marker_ran'
        .tr(namedArgs: {'time': time, 'what': _labelKey[m.kind]!.tr()});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 기기 종류별로 색을 나누지는 않는다 — 온·습도 선과 색이 경쟁해 정작
    // 읽어야 할 곡선이 묻힌다. 대신 Figma가 정한 메인컬러 한 가지로 또렷하게.
    final fg = AppTheme.chartMarkerGlyph(theme.brightness);
    final bg = AppTheme.chartMarkerChip(theme.brightness);
    const size = StatsEnvChart.markerChip;

    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          for (final m in markers)
            if (m.positionIn(start: window.start, end: window.end)
                case final p?)
              Positioned(
                // 양 끝에서 칩이 잘리지 않게 안쪽으로 붙인다.
                left: (p * c.maxWidth - size / 2)
                    .clamp(0.0, (c.maxWidth - size).clamp(0.0, double.infinity)),
                top: 0,
                child: Tooltip(
                  message: _label(m),
                  triggerMode: TooltipTriggerMode.tap,
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _glyph(m.kind, fg),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// X축 시각 라벨. 눈금은 [StatsWindow]가 정한다 — 창 시작부터 6시간 간격 4개.
///
/// Figma는 라벨을 눈금에 **왼쪽 맞춤**했다. 가운데 맞추면 첫 라벨이 플롯 밖으로
/// 나가고 마지막 라벨이 밴드 위로 올라탄다.
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.window, required this.style});

  final StatsWindow window;
  final TextStyle? style;

  /// `오후 10시`가 잘리지 않는 폭.
  static const double _labelWidth = 56;

  @override
  Widget build(BuildContext context) {
    final ticks = window.ticks;
    if (ticks.isEmpty) return const SizedBox(height: StatsEnvChart.labelHeight);

    return SizedBox(
      height: StatsEnvChart.labelHeight,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final t in ticks)
              Positioned(
                left: (t.position * c.maxWidth).clamp(
                  0.0,
                  (c.maxWidth - _labelWidth).clamp(0.0, double.infinity),
                ),
                child: SizedBox(
                  width: _labelWidth,
                  child: Text(
                    (t.isAm ? 'home_chart_time_am' : 'home_chart_time_pm')
                        .tr(namedArgs: {'h': '${t.hour12}'}),
                    style: style,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
