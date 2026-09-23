import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/mist_duration.dart';
import 'package:vivanaut/features/home/domain/mist_lock.dart';

void main() {
  group('MistLock', () {
    test('초기 상태는 잠금 해제', () {
      expect(const MistLock(lockedUntil: null).isLocked(DateTime(2026, 8, 5)),
          isFalse);
    });

    test('잠금 시작 후 5초 동안 잠김', () {
      final lock = MistLock.startingAt(DateTime(2026, 8, 5, 12));
      expect(lock.isLocked(DateTime(2026, 8, 5, 12, 0, 4)), isTrue);
    });

    test('정확히 5초 뒤 해제', () {
      final lock = MistLock.startingAt(DateTime(2026, 8, 5, 12));
      expect(lock.isLocked(DateTime(2026, 8, 5, 12, 0, 5)), isFalse);
    });

    test('락 지속시간은 PRD 명시값 5초', () {
      expect(MistLock.duration, const Duration(seconds: 5));
    });

    test('남은 시간 — 해제 상태면 zero', () {
      final lock = MistLock.startingAt(DateTime(2026, 8, 5, 12));
      expect(lock.remaining(DateTime(2026, 8, 5, 12, 0, 2)),
          const Duration(seconds: 3));
      expect(lock.remaining(DateTime(2026, 8, 5, 12, 0, 9)), Duration.zero);
    });

    test('분사 시간 + 2초 동안 잠근다 — 10초 분무 중 다시 누를 수 없다', () {
      expect(MistLock.lockFor(MistDuration.fiveSeconds),
          const Duration(seconds: 7));
      final lock = MistLock.startingAt(DateTime(2026, 9, 23, 12),
          mist: MistDuration.tenSeconds);
      expect(lock.isLocked(DateTime(2026, 9, 23, 12, 0, 11)), isTrue);
      expect(lock.isLocked(DateTime(2026, 9, 23, 12, 0, 12)), isFalse);
    });

    test('분사 시간을 모르면 PRD 최소값 5초', () {
      expect(MistLock.lockFor(null), MistLock.duration);
    });
  });
}
