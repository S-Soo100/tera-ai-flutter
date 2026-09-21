import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../domain/activity_axis.dart';
import '../../domain/activity_summary.dart';
import 'activity_day_chart.dart';

class ActivityWeekChart extends StatelessWidget {
  const ActivityWeekChart({super.key, required this.days});
  final List<ActivityDaySummary> days;
  @override
  Widget build(BuildContext context) {
    final peak = days.fold<double>(0, (v, d) => math.max(v, d.seconds ?? 0));
    // 축은 가변이다 — 3시간을 하한으로 두면 하루 10분짜리 주는 막대가 전부
    // 바닥에 붙은 점이 된다(2026-09-21 신고). [ActivityAxis] 참조.
    return ActivityBars(
        buckets: days,
        axis: ActivityAxis.forPeak(peak),
        weekly: true,
        labels: List.generate(7, (i) => 'activity_weekday_$i'.tr()));
  }
}
