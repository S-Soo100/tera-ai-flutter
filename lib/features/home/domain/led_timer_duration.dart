/// LED 작동 시간(Figma 1106:4127 "작동 시간" 30분/1시간/2시간/3시간/계속).
///
/// **2026-09-16 사용자 결정 — 서버·펌웨어 확인 전 미리 구현.** `led_on`에
/// `payload.duration_ms`를 실어 보내면 팬 타이머(`fan_on` + duration_ms)처럼
/// 펌웨어가 시간 뒤 자동 OFF 한다고 **가정**한다. 계약 확인 요청은
/// `docs/handoffs/2026-09-16-server-request-led-timer-schedule-payload.md`.
/// '계속'은 duration 없음(null).
enum LedTimerDuration {
  m30(30),
  h1(60),
  h2(120),
  h3(180);

  const LedTimerDuration(this.minutes);

  final int minutes;

  int get milliseconds => minutes * 60000;

  /// 칩 라벨 i18n 키 — 팬 타이머와 같은 `home_timer_30m` / `home_timer_1h` 식.
  String get labelKey =>
      minutes < 60 ? 'home_timer_${minutes}m' : 'home_timer_${minutes ~/ 60}h';
}
