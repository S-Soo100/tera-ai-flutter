import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/activity_colors.dart';
import '../../domain/activity_axis.dart';
import '../../domain/activity_summary.dart';

String activityDuration(double? seconds) {
  if (seconds == null) return '--';
  if (seconds > 0 && seconds < 60) {
    return 'activity_seconds'
        .tr(namedArgs: {'value': seconds.ceil().toString()});
  }
  final minutes = seconds ~/ 60;
  return 'activity_duration'.tr(
      namedArgs: {'hours': '${minutes ~/ 60}', 'minutes': '${minutes % 60}'});
}

class ActivityDayChart extends StatelessWidget {
  const ActivityDayChart({super.key, required this.hours});
  final List<ActivityBucket> hours;
  @override
  Widget build(BuildContext context) => ActivityBars(
      // 한 시간짜리 버킷이라 축도 한 시간 고정 — 0~60분 라벨을 그대로 읽는다.
      buckets: hours,
      axis: ActivityAxis.forPeak(3600),
      weekly: false,
      labels: List.generate(4, (index) => 'activity_hour_${index * 6}'.tr()));
}

/// 주간 축 눈금 라벨. 90분 이하 축은 **분**으로 읽는다 — 시간으로 쓰면
/// `1.3h`·`0.3h`처럼 시계로 못 읽는 숫자가 된다.
String activityAxisLabel(ActivityAxis axis, double seconds) => axis.inMinutes
    ? 'activity_minutes_axis'
        .tr(namedArgs: {'value': (seconds / 60).round().toString()})
    : 'activity_hours_axis'
        .tr(namedArgs: {'value': NumberFormat('0.#').format(seconds / 3600)});

/// Original Figma graph is 369×256 with a 224px plot and right-hand axis.
/// Empty buckets carry a dash; measured zero remains an explicit 0 tooltip.
class ActivityBars extends StatelessWidget {
  const ActivityBars(
      {super.key,
      required this.buckets,
      required this.axis,
      required this.labels,
      required this.weekly});
  // Seven 32px rows: the highest tick ends the first row, zero ends the last.
  static const double rowHeight = 32;
  static const double plotHeight = 224;
  static const double valueHeight = plotHeight - rowHeight;

  final List<ActivityBucket> buckets;
  final ActivityAxis axis;
  final List<String> labels;
  final bool weekly;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final labelStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
        fontSize: 12,
        height: 1.193359375,
        letterSpacing: -.24,
        fontWeight: FontWeight.w500,
        color: glass.deviceOff);
    final peak = buckets.fold<double>(0, (v, b) => math.max(v, b.seconds ?? 0));
    final minimum = buckets
        .map((bucket) => bucket.seconds)
        .whereType<double>()
        .fold<double>(double.infinity, math.min);
    return SizedBox(
        height: 256,
        child: LayoutBuilder(builder: (context, constraints) {
          final plotWidth = math.max(0.0, constraints.maxWidth - 28);
          final width = plotWidth / (buckets.isEmpty ? 1 : buckets.length);
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
                left: 0,
                top: 0,
                width: constraints.maxWidth,
                height: 256,
                child: CustomPaint(
                    painter: _ActivityGrid(glass.border,
                        plotWidth: plotWidth, divisions: labels.length))),
            for (var tick = 0; tick <= 6; tick++)
              Positioned(
                  right: 0,
                  top: tick * rowHeight,
                  width: 26,
                  height: rowHeight,
                  child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                          weekly
                              ? activityAxisLabel(axis, axis.ticks[6 - tick])
                              : '${60 - tick * 10}',
                          style: labelStyle,
                          textAlign: TextAlign.left))),
            for (var i = 0; i < buckets.length; i++)
              Positioned(
                  left: i * width,
                  top: 0,
                  width: width,
                  height: 224,
                  child: Tooltip(
                      message:
                          '${weekly ? labels[i] : 'activity_hour'.tr(namedArgs: {
                                  'hour': '$i'
                                })}: '
                          '${activityDuration(buckets[i].seconds)}${buckets[i].isEstimated ? ' (${'activity_estimated'.tr()})' : ''}',
                      child: Semantics(
                          label:
                              '${weekly ? labels[i] : i}: ${activityDuration(buckets[i].seconds)}',
                          child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomCenter,
                              children: [
                                if (buckets[i].seconds == null)
                                  Positioned(
                                      bottom: 1,
                                      child: Text('--',
                                          style: labelStyle.copyWith(
                                              fontSize: 10)))
                                else ...[
                                  Container(
                                      width: weekly
                                          ? math.min(28, width - 8)
                                          : math.max(1, width - 4),
                                      height: (valueHeight *
                                              buckets[i].seconds! /
                                              axis.maxSeconds)
                                          .clamp(0, valueHeight),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(20)),
                                        color: buckets[i].seconds == peak &&
                                                peak > 0
                                            ? ActivityColors.peak
                                            : buckets[i].seconds == minimum
                                                ? glass.deviceOff
                                                : glass.bodySecondary,
                                      )),
                                  if (weekly)
                                    Positioned(
                                        bottom: (valueHeight *
                                                    buckets[i].seconds! /
                                                    axis.maxSeconds +
                                                2)
                                            .clamp(2, valueHeight + 2),
                                        child: Text(
                                            activityDuration(
                                                buckets[i].seconds),
                                            style: labelStyle.copyWith(
                                                fontSize: 14,
                                                letterSpacing: -.7,
                                                color: buckets[i].seconds ==
                                                            peak &&
                                                        peak > 0
                                                    ? ActivityColors.peak
                                                    : glass.bodySecondary))),
                                ],
                              ])))),
            for (var i = 0; i < labels.length; i++)
              Positioned(
                  left: plotWidth / labels.length * i + 4,
                  top: 234,
                  child: Text(labels[i], style: labelStyle)),
          ]);
        }));
  }
}

class _ActivityGrid extends CustomPainter {
  const _ActivityGrid(this.color,
      {required this.plotWidth, required this.divisions});
  final double plotWidth;
  final int divisions;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    // Figma export: half-point strokes in the existing border palette color.
    final paint = Paint()
      ..color = color
      ..strokeWidth = .5;
    for (var i = 0; i <= divisions; i++) {
      final x = plotWidth * i / divisions;
      if (i == 0 || i == divisions) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      } else {
        for (double y = 0; y < size.height; y += 4) {
          canvas.drawLine(
              Offset(x, y), Offset(x, math.min(y + 2, size.height)), paint);
        }
      }
    }
    for (var i = 0; i <= 7; i++) {
      final y = ActivityBars.rowHeight * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ActivityGrid oldDelegate) =>
      color != oldDelegate.color ||
      plotWidth != oldDelegate.plotWidth ||
      divisions != oldDelegate.divisions;
}
