/// "어젯밤" 시작 = 어제 22:00(로컬).
DateTime lastNightSince(DateTime now) =>
    DateTime(now.year, now.month, now.day, 22)
        .subtract(const Duration(days: 1));

/// "어젯밤" 끝 = 오늘 06:00. 단 지금이 06시 이전이면 현재 시각(밤 진행 중).
DateTime lastNightEnd(DateTime now) {
  final six = DateTime(now.year, now.month, now.day, 6);
  return now.isBefore(six) ? now : six;
}

/// "어젯밤"의 서버 day_key("YYYY-MM-DD", 20:00 KST 경계) — 지금이 20시
/// 이전이면 어제 날짜, 이후면 오늘 날짜. 서버와 같은 정의: 시각에서
/// 20시간을 뺀 날짜(기기 로컬 = KST 전제, 앱 전반의 22~06 창과 동일 전제).
String lastNightDayKey(DateTime now) {
  final d = now.subtract(const Duration(hours: 20));
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}
