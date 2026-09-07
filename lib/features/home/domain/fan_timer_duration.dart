/// 팬 일회성 타이머 길이 (PRD §4.2.1).
///
/// `fan_on` + `payload.duration_ms`로 보내면 **펌웨어가 시간 뒤 자동 OFF**한다
/// — 앱이 ON→지연 OFF로 흉내내면 앱이 백그라운드로 가는 순간 팬이 계속 돈다.
/// 계약 상한 2h(7,200,000ms), 취소는 `fan_off`
/// (`docs/backend-handoff-2026-08-14-summary.md` §1.3).
/// 히터 타이머는 미지원 — 현 보드에 히터 미탑재.
enum FanTimerDuration {
  m10(10),
  m30(30),
  h1(60),
  h2(120);

  const FanTimerDuration(this.minutes);

  final int minutes;

  Map<String, dynamic> get payload => {'duration_ms': minutes * 60000};

  /// 칩 라벨 i18n 키. `home_timer_10m` / `home_timer_1h` 식.
  String get labelKey =>
      minutes < 60 ? 'home_timer_${minutes}m' : 'home_timer_${minutes ~/ 60}h';
}
