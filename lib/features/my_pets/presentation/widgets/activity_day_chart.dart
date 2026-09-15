import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/activity_colors.dart';
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
      buckets: hours,
      maxSeconds: 3600,
      weekly: false,
      labels: List.generate(4, (index) => 'activity_hour_${index * 6}'.tr()));
}

/// Original Figma graph is 369×256 with a 224px plot and right-hand axis.
/// Empty buckets carry a dash; measured zero remains an explicit 0 tooltip.
class ActivityBars extends StatelessWidget {
  const ActivityBars(
      {super.key,
      required this.buckets,
      required this.maxSeconds,
      required this.labels,
      required this.weekly});
  final List<ActivityBucket> buckets;
  final double maxSeconds;
  final List<String> labels;
  final bool weekly;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final labelStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
        fontSize: 12,
        letterSpacing: -.24,
        fontWeight: FontWeight.w500,
        color: glass.deviceOff);
    final peak = buckets.fold<double>(0, (v, b) => math.max(v, b.seconds ?? 0));
    return SizedBox(
        height: 256,
        child: LayoutBuilder(builder: (context, constraints) {
          final plotWidth = math.max(0.0, constraints.maxWidth - 28);
          final width = plotWidth / (buckets.isEmpty ? 1 : buckets.length);
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
                left: 0,
                top: 0,
                width: plotWidth,
                height: 224,
                child: CustomPaint(
                    painter:
                        _ActivityGrid(glass.border, timeDividers: !weekly))),
            for (var tick = 0; tick <= 6; tick++)
              Positioned(
                  right: 0,
                  top: tick * (224 / 6) - (tick == 0 ? 0 : 7),
                  width: 26,
                  child: Text(
                      weekly
                          ? 'activity_hours_axis'.tr(namedArgs: {
                              'value': NumberFormat('0.#')
                                  .format(maxSeconds / 3600 * (6 - tick) / 6)
                            })
                          : '${60 - tick * 10}',
                      style: labelStyle,
                      textAlign: TextAlign.right)),
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
                                      height: (224 *
                                              buckets[i].seconds! /
                                              maxSeconds)
                                          .clamp(0, 224),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(20)),
                                        color: buckets[i].seconds == peak &&
                                                peak > 0
                                            ? ActivityColors.peak
                                            : glass.bodySecondary,
                                      )),
                                  if (weekly)
                                    Positioned(
                                        bottom: (224 *
                                                    buckets[i].seconds! /
                                                    maxSeconds +
                                                2)
                                            .clamp(2, 226),
                                        child: Text(
                                            activityDuration(
                                                buckets[i].seconds),
                                            style: labelStyle.copyWith(
                                                fontSize: 14,
                                                letterSpacing: -.7,
                                                color: glass.bodySecondary))),
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
  const _ActivityGrid(this.color, {required this.timeDividers});
  final bool timeDividers;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    // Figma time dividers: midnight, 06:00, noon, 18:00.
    for (var i = 0; timeDividers && i < 4; i++) {
      final x = size.width * i / 4;
      for (double y = 0; y < size.height; y += 8) {
        canvas.drawLine(
            Offset(x, y), Offset(x, math.min(y + 4, size.height)), paint);
      }
    }
    for (var i = 0; i <= 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ActivityGrid oldDelegate) =>
      color != oldDelegate.color || timeDividers != oldDelegate.timeDividers;
}
