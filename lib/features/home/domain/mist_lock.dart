/// PRD §3.4 분무 버튼 예외 처리 — 명령 송출 후 5초간 비활성화(중복 클릭 방지).
///
/// 위젯 로컬 타이머가 아니라 상태값으로 두는 이유: 서브탭을 오가거나 세트를
/// 스와이프해도 락이 유지돼야 한다.
class MistLock {
  final DateTime? lockedUntil;

  const MistLock({required this.lockedUntil});

  /// PRD 명시값.
  static const duration = Duration(seconds: 5);

  factory MistLock.startingAt(DateTime now) =>
      MistLock(lockedUntil: now.add(duration));

  bool isLocked(DateTime now) =>
      lockedUntil != null && now.isBefore(lockedUntil!);

  Duration remaining(DateTime now) {
    if (lockedUntil == null) return Duration.zero;
    final d = lockedUntil!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}
