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
  /// 주간은 2026-08-12에 열었다. Figma에 제목만 있어 오래 비워뒀지만
  /// (*"7일, 30일은 어떻게 봐야할지 감이 안 옴"*), 24시간 차트가 자리를 잡은 뒤
  /// **그걸 레퍼런스로** 같은 규칙(하루 경계 07:00 · 미도래 밴드 · 스크러버)을
  /// 7일로 늘렸다.
  ///
  /// 월간은 아직이다. 30칸을 한 화면에 그리면 일별 점이 뭉개져, 주간처럼
  /// 늘리는 것만으로는 안 된다 — 별도 설계가 필요하다.
  bool get isReady => this != StatsPeriod.monthly;

  /// 차트 제목 키.
  String get chartTitleKey => switch (this) {
        StatsPeriod.weekly => 'stats_weekly_title',
        _ => 'stats_daily_title',
      };
}
