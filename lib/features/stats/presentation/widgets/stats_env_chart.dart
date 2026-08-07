import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/chart_time_axis.dart';
import '../../domain/axis_bounds.dart';
import '../../domain/stats_chart_data.dart';

/// Figma `온습도 그래프 - 24시` 본체.
///
/// 좌축 = 온도, 우축 = 습도, X축 = 6시간 간격 시각.
/// 두 지표는 단위가 달라 [StatsChartData]에서 **각자 0~1로 정규화**해 온다.
/// 그래서 차트의 Y는 항상 0~1이고, 사람이 읽는 눈금은 좌우 라벨 컬럼이 담당한다.
class StatsEnvChart extends StatelessWidget {
  const StatsEnvChart({super.key, required this.data});

  final StatsChartData data;

  static const chartKey = Key('stats_env_chart');

  /// 플롯 영역 높이. Figma의 Y축 라벨 컬럼(104px, 6단)에 맞춘 값.
  static const double _plotHeight = 180;

  @override
  Widget build(BuildContext context) {
    final onVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: onVariant);

    return Column(
      key: chartKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AxisLabels(
                axis: data.tempAxis,
                format: (v) => 'stats_axis_temp'.tr(
                  namedArgs: {'v': v.toStringAsFixed(0)},
                ),
                style: labelStyle,
                alignment: TextAlign.right,
              ),
              const SizedBox(width: AppStyles.spacing4),
              Expanded(child: _Plot(data: data)),
              const SizedBox(width: AppStyles.spacing4),
              _AxisLabels(
                axis: data.humidAxis,
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
        _TimeAxis(data: data, style: labelStyle),
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

  @override
  Widget build(BuildContext context) {
    if (axis == null) return const SizedBox.shrink();
    final ticks = axis!.ticks.reversed.toList(); // 위 → 아래

    return SizedBox(
      width: 34,
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

class _Plot extends StatelessWidget {
  const _Plot({required this.data});

  final StatsChartData data;

  @override
  Widget build(BuildContext context) {
    final grid = Theme.of(context).dividerColor;

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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      _tooltipText(s),
                      Theme.of(context).textTheme.labelSmall ??
                          const TextStyle(),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          if (data.tempPoints.length > 1)
            _bar(data.tempPoints, AppTheme.chartTemperature),
          if (data.humidPoints.length > 1)
            _bar(data.humidPoints, AppTheme.chartHumidity),
        ],
      ),
    );
  }

  /// 정규화된 y를 사람이 읽는 값으로 되돌려 보여준다. 툴팁에 0.42가 뜨면
  /// 아무 의미가 없다.
  String _tooltipText(LineBarSpot spot) {
    final isTemp = spot.barIndex == 0 && data.tempPoints.length > 1;
    final axis = isTemp ? data.tempAxis : data.humidAxis;
    if (axis == null) return '';
    final real = axis.min + spot.y * axis.span;
    return isTemp
        ? 'stats_axis_temp'.tr(namedArgs: {'v': real.toStringAsFixed(1)})
        : 'stats_axis_humid'.tr(namedArgs: {'v': real.toStringAsFixed(0)});
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

/// X축 시각 라벨. 홈 미니 차트와 **같은 계산기**([chartTimeTicks])를 쓴다.
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.data, required this.style});

  final StatsChartData data;
  final TextStyle? style;

  static const double _labelWidth = 52;

  @override
  Widget build(BuildContext context) {
    final ticks = chartTimeTicks(from: data.from, to: data.to);
    if (ticks.isEmpty) return const SizedBox(height: 14);

    // 플롯 영역은 좌우 라벨 컬럼(34 + 여백 4)만큼 안쪽으로 들어가 있다.
    // 같은 만큼 밀어줘야 눈금이 선과 같은 자리를 가리킨다.
    const inset = 34 + AppStyles.spacing4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: inset),
      child: SizedBox(
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
      ),
    );
  }
}
