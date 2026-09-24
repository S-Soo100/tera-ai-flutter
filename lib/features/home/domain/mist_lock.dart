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

  /// 이어 보내는 회차 간격 — 3초 분사 + 2초 쉼. 서버가 10초를 5+5초로 이을 때
  /// 분사가 끝나고 약 2초 뒤 다음을 보낸 실측(2026-09-25)에 맞췄다. 분사 중에
  /// 보내면 기기가 `busy`로 거절한다.
  static const partInterval = Duration(seconds: 5);

  /// 응답이 늦을 때 다시 누르지 못하게 잡아 두는 길이 — 서버가 무응답(no_ack)을
  /// 확정하는 30초. 앱의 8초 안내 뒤 풀리면 늦게 도착한 명령과 겹쳐 두 번
  /// 분사될 수 있다(2026-09-25 점검).
  static const unconfirmedHold = Duration(seconds: 30);

  /// [mist] 전체(이어 보내기 포함) 동안 잠근다.
  static Duration lockFor(MistDuration? mist) {
    final parts = mist?.parts ?? 1;
    final spray = parts <= 1
        ? Duration(milliseconds: mist?.milliseconds ?? 0) + tail
        : partInterval * (parts - 1) +
            const Duration(milliseconds: MistDuration.partMilliseconds) +
            tail;
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
