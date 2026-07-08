/// "어젯밤" 시작 = 어제 22:00(로컬).
DateTime lastNightSince(DateTime now) =>
    DateTime(now.year, now.month, now.day, 22)
        .subtract(const Duration(days: 1));

/// "어젯밤" 끝 = 오늘 06:00. 단 지금이 06시 이전이면 현재 시각(밤 진행 중).
DateTime lastNightEnd(DateTime now) {
  final six = DateTime(now.year, now.month, now.day, 6);
  return now.isBefore(six) ? now : six;
}
