/// MyCre uses Korea's fixed UTC+09:00 civil calendar, independently of the host
/// timezone. [startUtc, endUtc) is always a half-open range of instants.
class ActivityWindow {
  const ActivityWindow({required this.startUtc, required this.endUtc});
  static const kstOffset = Duration(hours: 9);
  factory ActivityWindow.day(int year, int month, int day) {
    final start = DateTime.utc(year, month, day).subtract(kstOffset);
    return ActivityWindow(
        startUtc: start, endUtc: start.add(const Duration(days: 1)));
  }
  factory ActivityWindow.containing(DateTime instant) {
    final civil = instant.toUtc().add(kstOffset);
    return ActivityWindow.day(civil.year, civil.month, civil.day);
  }
  factory ActivityWindow.weekContaining(ActivityWindow day) {
    final start =
        day.startUtc.subtract(Duration(days: day.kstDate.weekday - 1));
    return ActivityWindow(
        startUtc: start, endUtc: start.add(const Duration(days: 7)));
  }
  final DateTime startUtc;
  final DateTime endUtc;

  /// Calendar fields only; this UTC-encoded value is not a Korean instant.
  DateTime get kstDate => startUtc.toUtc().add(kstOffset);
  ActivityWindow shiftDays(int days) => ActivityWindow(
      startUtc: startUtc.add(Duration(days: days)),
      endUtc: endUtc.add(Duration(days: days)));
  @override
  bool operator ==(Object other) =>
      other is ActivityWindow &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc;
  @override
  int get hashCode => Object.hash(startUtc, endUtc);
}
