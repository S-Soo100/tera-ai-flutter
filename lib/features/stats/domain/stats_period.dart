/// 통계 조회 기간. 기획안 §4.3.1.
///
/// | 기간 | 범위 | 포인트 단위 |
/// |---|---|---|
/// | 일간 | 선택 날짜 `07:00 ~ 익일 07:00` | 10분 |
/// | 주간 | 최근 7일 | 1일 |
/// | 월간 | 최근 30일 | 1일 |
///
/// **일간의 07:00 경계는 §3.1 ①(당일)과 같은 규칙이다.** 야행성이라 자정이
/// 하루의 경계가 아니고, 밤 활동이 두 날짜로 쪼개지면 안 된다.
enum StatsPeriod {
  daily,
  weekly,
  monthly;

  String get labelKey => switch (this) {
        StatsPeriod.daily => 'stats_period_daily',
        StatsPeriod.weekly => 'stats_period_weekly',
        StatsPeriod.monthly => 'stats_period_monthly',
      };

  /// 이 기간의 차트가 그려지는가.
  ///
  /// 주간·월간은 **디자인이 없다.** Figma에 제목만 있고, 피드백에도
  /// *"7일, 30일은 어떻게 봐야할지 감이 안 옴"*이라 적혀 있다. 임의로 그리지
  /// 않고 자리만 잡아둔다(기획안 §6 D).
  bool get isReady => this == StatsPeriod.daily;
}
