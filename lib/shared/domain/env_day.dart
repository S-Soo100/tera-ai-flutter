/// 온습도 상세의 **자정 경계 하루 창** (PRD §3.1 ③, 계획서 2026-09-02 T3).
///
/// [DayWindow](07:00 경계, 어젯밤 리포트)·[ChartWindow](6시간 전진 프레임)와
/// **다른 개념**이다 — 온습도 상세는 달력 날짜 페이징이라 자정~자정이다.
/// 혼용하면 같은 밤을 화면마다 다른 날로 말하게 된다.
class EnvDay {
  /// 자정으로 정규화된 **로컬** 날짜. (UTC로 만들면 페이저 날짜가 하루 밀린다.)
  final DateTime date;

  const EnvDay(this.date);

  /// [now]가 속한 하루. 시각을 버리고 자정으로 정규화한다.
  factory EnvDay.of(DateTime now) =>
      EnvDay(DateTime(now.year, now.month, now.day));

  /// 하루의 시작(포함). x = 0.
  DateTime get start => date;

  /// 하루의 끝(제외) = 다음 날 자정. 달력 연산이라 월말·서머타임에도 안전하다.
  DateTime get end => DateTime(date.year, date.month, date.day + 1);

  /// 지금 기준 오늘인가. 결정적 검증이 필요한 자리는 [containsNow]에 now를
  /// 주입해서 쓴다 — 이 getter는 UI 편의용이다.
  bool get isToday => containsNow(DateTime.now());

  EnvDay get previous => EnvDay(DateTime(date.year, date.month, date.day - 1));

  EnvDay get next => EnvDay(DateTime(date.year, date.month, date.day + 1));

  /// [now]가 이 하루 안인가. 시작 포함, 끝 제외 — 자정은 **그 날**이다.
  bool containsNow(DateTime now) =>
      !now.isBefore(start) && now.isBefore(end);

  // StateProvider 상태로 쓰므로 값 동등성이 필요하다 — 없으면 같은 날로
  // 갱신해도 다른 인스턴스라 리빌드가 돈다.
  @override
  bool operator ==(Object other) => other is EnvDay && other.date == date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() => 'EnvDay(${date.year}-${date.month}-${date.day})';
}
