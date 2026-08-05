/// PRD §5-1.2 시간 정책: 당일 = 07:00 ~ 익일 07:00 (야행성 활동 주기 반영).
///
/// 자정이 아니라 **07:00**이 하루의 경계다. 06:59는 전날 창에 속한다.
/// 어젯밤 리포트(22~06시)의 `lastNightSince/lastNightEnd`와는 별개 개념이니
/// 혼용하지 말 것.
class DayWindow {
  /// 창 시작 (inclusive), 항상 07:00.
  final DateTime start;

  /// 창 끝 (exclusive), 항상 익일 07:00.
  final DateTime end;

  const DayWindow._(this.start, this.end);

  /// [now]가 속한 창.
  factory DayWindow.of(DateTime now) {
    final anchor = now.hour < dayStartHour
        ? DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);
    return DayWindow.forDate(anchor);
  }

  /// [date]의 날짜 부분을 기준으로 한 창 (날짜 스크롤러가 쓴다).
  factory DayWindow.forDate(DateTime date) {
    final s = DateTime(date.year, date.month, date.day, dayStartHour);
    return DayWindow._(s, s.add(const Duration(days: 1)));
  }

  /// 하루의 시작 시각(시). PRD 고정값.
  static const int dayStartHour = 7;

  /// 차트 X축 시작 시각(시). PRD §5-1.2 "전날 19:00부터".
  static const int chartStartHour = 19;

  /// 창을 대표하는 날짜(= 시작한 날). 날짜 라벨에 쓴다.
  DateTime get labelDate => DateTime(start.year, start.month, start.day);

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// 최근 24시간 실시간 차트 범위: 전날 19:00 ~ [now].
  static ({DateTime start, DateTime end}) chartRange(DateTime now) {
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return (
      start: DateTime(
          yesterday.year, yesterday.month, yesterday.day, chartStartHour),
      end: now,
    );
  }
}
