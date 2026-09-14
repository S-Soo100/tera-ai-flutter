/// Calendar days, not elapsed 24-hour periods (also correct across DST).
int calendarDaysAgo(DateTime timestamp, DateTime now) {
  final date = timestamp.toLocal();
  final today = now.toLocal();
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(date.year, date.month, date.day)).inDays;
}
