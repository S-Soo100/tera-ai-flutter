import 'dart:math' as math;

import 'week_range.dart';

enum WeekBarRole { empty, neutral, maximum, minimum }

/// Compare at displayed precision. A day holding both extremes uses maximum;
/// a single valid day or identical ranges has no meaningful relative extreme.
List<WeekBarRole> classifyWeekBars(List<DayMinMax> rows,
    {int fractionDigits = 1}) {
  final scale = math.pow(10, fractionDigits);
  int? normalized(double? value) => value != null && value.isFinite && value > 0
      ? (value * scale).round()
      : null;
  final values = rows
      .map((row) => (min: normalized(row.min), max: normalized(row.max)))
      .toList();
  final valid =
      values.where((row) => row.min != null || row.max != null).toList();
  final neutral = valid.length <= 1 || valid.toSet().length == 1;
  final highs = valid.map((row) => row.max).whereType<int>();
  final lows = valid.map((row) => row.min).whereType<int>();
  final high = highs.isEmpty ? null : highs.reduce(math.max);
  final low = lows.isEmpty ? null : lows.reduce(math.min);
  return [
    for (final row in values)
      if (row.min == null && row.max == null)
        WeekBarRole.empty
      else if (neutral)
        WeekBarRole.neutral
      else if (row.max != null && row.max == high)
        WeekBarRole.maximum
      else if (row.min != null && row.min == low)
        WeekBarRole.minimum
      else
        WeekBarRole.neutral,
  ];
}
