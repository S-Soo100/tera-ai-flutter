import 'mist_duration.dart';

/// PRD §3.4 분무 버튼 예외 처리 — 명령 송출 후 비활성화(중복 클릭 방지).
///
/// 위젯 로컬 타이머가 아니라 상태값으로 두는 이유: 서브탭을 오가거나 세트를
/// 스와이프해도 락이 유지돼야 한다.
class MistLock {
  final DateTime? lockedUntil;

  const MistLock({required this.lockedUntil});

  /// PRD 명시값 — 잠금의 **최소** 길이.
  static const duration = Duration(seconds: 5);

  /// 분사가 끝난 뒤 더 잠가 두는 여유. 텔레메트리가 3초 주기라 끝난 직후엔
  /// 아직 "작동 중"으로 보일 수 있다.
  static const tail = Duration(seconds: 2);

  /// [mist] 분사 동안은 잠근다 — 10초 분무 중 5초 만에 다시 누를 수 있으면
  /// 기기가 `busy`로 거절한다(2026-09-23, 분사 시간 5/10초 도입).
  static Duration lockFor(MistDuration? mist) {
    final spray = Duration(milliseconds: mist?.milliseconds ?? 0) + tail;
    return spray > duration ? spray : duration;
  }

  factory MistLock.startingAt(DateTime now, {MistDuration? mist}) =>
      MistLock(lockedUntil: now.add(lockFor(mist)));

  bool isLocked(DateTime now) =>
      lockedUntil != null && now.isBefore(lockedUntil!);

  Duration remaining(DateTime now) {
    if (lockedUntil == null) return Duration.zero;
    final d = lockedUntil!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}
