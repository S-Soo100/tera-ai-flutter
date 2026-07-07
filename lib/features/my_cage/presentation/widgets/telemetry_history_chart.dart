import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/device_targets.dart';
import '../../domain/telemetry_bucket.dart';
import '../supabase_module_providers.dart';

/// 연속 버킷을 gap 기준으로 분절한다.
///
/// 인접 버킷 간격이 [gapThreshold](기본 45분 = 30분×1.5)를 **초과**하면 그 지점에서
/// 선을 끊고 새 세그먼트를 시작한다. 오프라인으로 버킷이 통째로 빠진 구간을
/// 직선으로 잇지 않기 위함(문서 §4). [buckets]는 bucket 오름차순 정렬 가정.
/// 빈 리스트 → 빈 리스트.
List<List<TelemetryBucket>> segmentByGap(
  List<TelemetryBucket> buckets, {
  Duration gapThreshold = const Duration(minutes: 45),
}) {
  if (buckets.isEmpty) return <List<TelemetryBucket>>[];
  final segments = <List<TelemetryBucket>>[];
  var current = <TelemetryBucket>[buckets.first];
  for (var i = 1; i < buckets.length; i++) {
    final gap = buckets[i].bucket.difference(buckets[i - 1].bucket);
    if (gap > gapThreshold) {
      segments.add(current);
      current = <TelemetryBucket>[];
    }
    current.add(buckets[i]);
  }
  segments.add(current);
  return segments;
}

/// 차트가 다루는 지표(온도/습도). 값 접근·목표범위·표기 자릿수를 캡슐화.
enum _Metric { temperature, humidity }

extension _MetricX on _Metric {
  double? avg(TelemetryBucket b) =>
      this == _Metric.temperature ? b.tAvg : b.hAvg;
  double? minVal(TelemetryBucket b) =>
      this == _Metric.temperature ? b.tMin : b.hMin;
  double? maxVal(TelemetryBucket b) =>
      this == _Metric.temperature ? b.tMax : b.hMax;

  double? targetLo(DeviceTargets t) =>
      this == _Metric.temperature ? t.tempMin : t.humidMin;
  double? targetHi(DeviceTargets t) =>
      this == _Metric.temperature ? t.tempMax : t.humidMax;
  bool hasTarget(DeviceTargets t) =>
      this == _Metric.temperature ? t.hasTempBand : t.hasHumidBand;

  int get fractionDigits => this == _Metric.temperature ? 1 : 0;
}

/// gap-세그먼트를, 해당 metric의 avg/min/max가 **모두 존재**하는 연속 run들로
/// 다시 쪼갠다. 행은 있으나 센서값이 null인 버킷에서 선을 잇지 않기 위함.
List<List<TelemetryBucket>> _runsWithValues(
  List<TelemetryBucket> seg,
  _Metric m,
) {
  final runs = <List<TelemetryBucket>>[];
  var cur = <TelemetryBucket>[];
  for (final b in seg) {
    final ok = m.avg(b) != null && m.minVal(b) != null && m.maxVal(b) != null;
    if (ok) {
      cur.add(b);
    } else if (cur.isNotEmpty) {
      runs.add(cur);
      cur = <TelemetryBucket>[];
    }
  }
  if (cur.isNotEmpty) runs.add(cur);
  return runs;
}

/// 사육장 온습도 추이 섹션 (telemetry_30m 기반, 30분 집계 장기 추이).
///
/// 통합 카드 셸의 세 번째 섹션으로 embedded 렌더링된다(패딩·타이포를 형제
/// 섹션과 맞춤). [currentDeviceProvider]로 device를 직접 watch하므로 파라미터
/// 불필요. device 없음/로딩 → 빈 위젯.
class TelemetryHistoryChart extends ConsumerWidget {
  const TelemetryHistoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(currentDeviceProvider).valueOrNull;
    if (device == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'telemetry_chart_title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const _RangeSelector(),
          const SizedBox(height: 16),
          _ChartArea(deviceId: device.id),
        ],
      ),
    );
  }
}

// ── 기간 세그먼트 셀렉터 (24시간/7일/30일) ────────────────────────────────────

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(telemetryRangeProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<TelemetryRange>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: TelemetryRange.values
            .map(
              (r) => ButtonSegment<TelemetryRange>(
                value: r,
                label: Text(r.labelKey.tr()),
              ),
            )
            .toList(),
        selected: {range},
        onSelectionChanged: (selection) {
          ref.read(telemetryRangeProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}

// ── 차트 영역 (history + targets 소비) ────────────────────────────────────────

class _ChartArea extends ConsumerWidget {
  const _ChartArea({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(telemetryRangeProvider);
    final historyAsync = ref.watch(telemetryHistoryProvider(deviceId));
    // device_settings 행이 없으면 null → 목표 밴드 미표시(임의 목표값 금지).
    final targets = ref.watch(deviceTargetsProvider(deviceId)).valueOrNull;

    return historyAsync.when(
      loading: () => const _ChartSkeleton(),
      error: (_, __) => const _ChartError(),
      data: (buckets) {
        if (buckets.isEmpty) return const _ChartEmpty();
        final segments = segmentByGap(buckets);
        return Column(
          children: [
            _MetricChart(
              segments: segments,
              metric: _Metric.temperature,
              targets: targets,
              range: range,
            ),
            const SizedBox(height: 20),
            _MetricChart(
              segments: segments,
              metric: _Metric.humidity,
              targets: targets,
              range: range,
            ),
          ],
        );
      },
    );
  }
}

// ── 단일 지표 차트 (평균선 + min/max 밴드 + 목표 밴드) ─────────────────────────

class _MetricChart extends StatelessWidget {
  const _MetricChart({
    required this.segments,
    required this.metric,
    required this.targets,
    required this.range,
  });

  final List<List<TelemetryBucket>> segments;
  final _Metric metric;
  final DeviceTargets? targets;
  final TelemetryRange range;

  static const double _chartHeight = 180;
  static const double _halfBucketMs = 15 * 60 * 1000; // 15분 (단일 포인트 여백)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lineColor =
        metric == _Metric.temperature ? cs.primary : cs.secondary;

    // ── bars/band 구성 + betweenBars 인덱스 추적 + Y/X 경계 계산 ──
    final lineBars = <LineChartBarData>[];
    final betweens = <BetweenBarsData>[];
    final avgRuns = <int, List<TelemetryBucket>>{}; // avgBarIndex → run

    double? loY, hiY, minX, maxX;
    for (final seg in segments) {
      for (final run in _runsWithValues(seg, metric)) {
        final minSpots = <FlSpot>[];
        final maxSpots = <FlSpot>[];
        final avgSpots = <FlSpot>[];
        for (final b in run) {
          final x = b.bucket.millisecondsSinceEpoch.toDouble();
          final mn = metric.minVal(b)!;
          final mx = metric.maxVal(b)!;
          final av = metric.avg(b)!;
          minSpots.add(FlSpot(x, mn));
          maxSpots.add(FlSpot(x, mx));
          avgSpots.add(FlSpot(x, av));
          loY = loY == null ? mn : math.min(loY, mn);
          hiY = hiY == null ? mx : math.max(hiY, mx);
          minX = minX == null ? x : math.min(minX, x);
          maxX = maxX == null ? x : math.max(maxX, x);
        }
        // 밴드: min 라인(fromIndex)과 max 라인(toIndex) 사이를 채움.
        final minIdx = lineBars.length;
        lineBars.add(_bandBar(minSpots, lineColor));
        final maxIdx = lineBars.length;
        lineBars.add(_bandBar(maxSpots, lineColor));
        betweens.add(
          BetweenBarsData(
            fromIndex: minIdx,
            toIndex: maxIdx,
            color: lineColor.withValues(alpha: 0.14),
          ),
        );
        // 평균선(맨 위). 인덱스를 run과 매핑해 툴팁에서 역참조.
        avgRuns[lineBars.length] = run;
        lineBars.add(_avgBar(avgSpots, run, lineColor));
      }
    }

    // 표시할 값이 하나도 없으면(모든 센서값 null) 빈 상태.
    if (lineBars.isEmpty ||
        loY == null ||
        hiY == null ||
        minX == null ||
        maxX == null) {
      return const _ChartEmpty();
    }

    // 목표 밴드가 있으면 Y범위에 포함시켜 밴드가 화면에 보이도록.
    final DeviceTargets? targetData = targets;
    final showTarget = targetData != null && metric.hasTarget(targetData);
    var dataLo = loY;
    var dataHi = hiY;
    if (showTarget) {
      dataLo = math.min(dataLo, metric.targetLo(targetData)!);
      dataHi = math.max(dataHi, metric.targetHi(targetData)!);
    }

    final span = dataHi - dataLo;
    final padY = span < 1 ? 1.0 : span * 0.12;
    final minY = dataLo - padY;
    final maxY = dataHi + padY;
    final yInterval = math.max((maxY - minY) / 4, 0.5);

    // 단일 포인트면 x축을 좌우로 벌려 렌더 가능하게.
    var lo = minX;
    var hi = maxX;
    if (hi <= lo) {
      lo -= _halfBucketMs;
      hi += _halfBucketMs;
    }
    final xInterval = math.max((hi - lo) / 4, 1.0);
    final xFormat = DateFormat(range == TelemetryRange.h24 ? 'HH:mm' : 'M/d');

    final titleKey = metric == _Metric.temperature
        ? 'telemetry_chart_temp'
        : 'telemetry_chart_humidity';
    final unitKey = metric == _Metric.temperature
        ? 'telemetry_chart_temp_unit'
        : 'telemetry_chart_humidity_unit';
    final icon = metric == _Metric.temperature
        ? Icons.thermostat
        : Icons.water_drop_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: lineColor),
            const SizedBox(width: 4),
            Text(
              '${titleKey.tr()} (${unitKey.tr()})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _chartHeight,
          child: LineChart(
            LineChartData(
              minX: lo,
              maxX: hi,
              minY: minY,
              maxY: maxY,
              lineBarsData: lineBars,
              betweenBarsData: betweens,
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  if (showTarget)
                    HorizontalRangeAnnotation(
                      y1: metric.targetLo(targetData)!,
                      y2: metric.targetHi(targetData)!,
                      color: cs.primary.withValues(alpha: 0.08),
                    ),
                ],
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value.toStringAsFixed(0),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: xInterval,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        xFormat.format(
                          DateTime.fromMillisecondsSinceEpoch(value.toInt()),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  final isBand = barData.barWidth == 0;
                  return spotIndexes.map((_) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: isBand
                            ? cs.outlineVariant.withValues(alpha: 0)
                            : lineColor.withValues(alpha: 0.4),
                        strokeWidth: isBand ? 0 : 1,
                      ),
                      FlDotData(
                        show: !isBand,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: lineColor,
                          strokeWidth: 0,
                        ),
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) =>
                      touchedSpots.map((s) {
                    final run = avgRuns[s.barIndex];
                    if (run == null) return null; // 밴드 바 → 툴팁 생략
                    final b = run[s.spotIndex];
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      b.bucket.millisecondsSinceEpoch,
                    );
                    final digits = metric.fractionDigits;
                    final unit = unitKey.tr();
                    final avgStr =
                        '${metric.avg(b)!.toStringAsFixed(digits)}$unit';
                    final minStr = metric.minVal(b)!.toStringAsFixed(digits);
                    final maxStr = metric.maxVal(b)!.toStringAsFixed(digits);
                    return LineTooltipItem(
                      '${DateFormat('M/d HH:mm').format(dt)}\n',
                      theme.textTheme.labelSmall!.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                      children: [
                        TextSpan(
                          text: avgStr,
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: lineColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '  ($minStr~$maxStr)',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        if (!showTarget) ...[
          const SizedBox(height: 6),
          Text(
            'telemetry_chart_no_target'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// min/max 외곽선 바 — 선은 숨기고(betweenBars 채움만 보이게) 밴드 경계로만 사용.
  LineChartBarData _bandBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      barWidth: 0,
      color: color.withValues(alpha: 0),
      dotData: const FlDotData(show: false),
    );
  }

  /// 평균선. 살짝 곡선 + 도트 off(단, partial 버킷만 옅은 점으로 "불완전" 표시).
  LineChartBarData _avgBar(
    List<FlSpot> spots,
    List<TelemetryBucket> run,
    Color color,
  ) {
    final partialXs = <double>{
      for (final b in run)
        if (b.isPartial) b.bucket.millisecondsSinceEpoch.toDouble(),
    };
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.15,
      preventCurveOverShooting: true,
      barWidth: 2,
      color: color,
      dotData: FlDotData(
        show: partialXs.isNotEmpty,
        checkToShowDot: (spot, _) => partialXs.contains(spot.x),
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 2.5,
          color: color.withValues(alpha: 0.45),
          strokeWidth: 0,
        ),
      ),
    );
  }
}

// ── 로딩 스켈레톤 (CPI 금지 → shimmer) ────────────────────────────────────────

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoading(width: double.infinity, height: 180, borderRadius: 12),
        SizedBox(height: 20),
        SkeletonLoading(width: double.infinity, height: 180, borderRadius: 12),
      ],
    );
  }
}

// ── 에러 ──────────────────────────────────────────────────────────────────────

class _ChartError extends StatelessWidget {
  const _ChartError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'error_generic'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────────────────────────────

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 30,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'telemetry_chart_empty'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
