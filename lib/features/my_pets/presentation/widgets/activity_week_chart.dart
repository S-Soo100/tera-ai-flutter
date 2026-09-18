import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../domain/activity_summary.dart';
import 'activity_day_chart.dart';

class ActivityWeekChart extends StatelessWidget {
  const ActivityWeekChart({super.key, required this.days});
  final List<ActivityDaySummary> days;
  @override
  Widget build(BuildContext context) {
    final peak = days.fold<double>(0, (v, d) => math.max(v, d.seconds ?? 0));
    // Default 3h Figma scale expands so a real peak is never clipped.
    final maxHours = math.max(3.0, (peak / 3600 / 3).ceil() * 3.0);
    return ActivityBars(
        buckets: days,
        maxSeconds: maxHours * 3600,
        weekly: true,
        labels: List.generate(7, (i) => 'activity_weekday_$i'.tr()));
  }
}
