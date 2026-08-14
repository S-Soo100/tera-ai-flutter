import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/running_timer.dart';

RunningTimer _t(DateTime endsAt) => RunningTimer(
      id: 't1',
      deviceId: 'd1',
      actuatorLabelKey: 'module_actuator_fan',
      durationMinutes: 30,
      endsAt: endsAt,
    );

void main() {
  group('RunningTimer.remaining', () {
    test('남은 시간 = endsAt - now', () {
      final t = _t(DateTime(2026, 8, 5, 12, 18, 20));
      expect(t.remaining(DateTime(2026, 8, 5, 12)),
          const Duration(minutes: 18, seconds: 20));
    });

    test('만료됐으면 Duration.zero — 음수로 안 간다', () {
      final t = _t(DateTime(2026, 8, 5, 12));
      expect(t.remaining(DateTime(2026, 8, 5, 12, 5)), Duration.zero);
    });
  });

  group('RunningTimer.isActive', () {
    test('남은 시간이 있으면 활성', () {
      expect(_t(DateTime(2026, 8, 5, 12, 1)).isActive(DateTime(2026, 8, 5, 12)),
          isTrue);
    });

    test('정확히 만료 시점이면 비활성', () {
      expect(_t(DateTime(2026, 8, 5, 12)).isActive(DateTime(2026, 8, 5, 12)),
          isFalse);
    });
  });

  group('formatRemaining — PRD 목업 문구', () {
    test('18분 20초', () {
      expect(
          formatRemaining(const Duration(minutes: 18, seconds: 20)), '18분 20초');
    });

    test('1분 미만은 초만', () {
      expect(formatRemaining(const Duration(seconds: 7)), '7초');
    });

    test('1시간 이상은 시간 포함', () {
      expect(formatRemaining(const Duration(hours: 1, minutes: 5, seconds: 3)),
          '1시간 5분 3초');
    });
  });

  group('RunningTimer.fanTimerFrom — commands 이력에서 계산 (A안)', () {
    Map<String, dynamic> cmd(String action, String status, String issuedAt,
            {int? durationMs}) =>
        {
          'id': 'c-$action-$issuedAt',
          'device_id': 'dev-1',
          'action': action,
          'status': status,
          'payload': durationMs == null ? null : {'duration_ms': durationMs},
          'issued_at': issuedAt,
        };

    final now = DateTime.parse('2026-08-14T12:00:00Z');

    test('duration 붙은 최신 fan_on → 진행 중 타이머', () {
      final t = RunningTimer.fanTimerFrom(
        [cmd('fan_on', 'acked', '2026-08-14T11:50:00Z', durationMs: 1800000)],
        now,
      );
      expect(t, isNotNull);
      expect(t!.durationMinutes, 30);
      expect(t.actuatorLabelKey, 'module_actuator_fan');
      expect(t.remaining(now), const Duration(minutes: 20));
    });

    test('더 최신 fan_off가 있으면 취소된 것 → null', () {
      final t = RunningTimer.fanTimerFrom([
        cmd('fan_off', 'acked', '2026-08-14T11:55:00Z'),
        cmd('fan_on', 'acked', '2026-08-14T11:50:00Z', durationMs: 1800000),
      ], now);
      expect(t, isNull);
    });

    test('rejected 명령은 없는 셈 — 그 아래 fan_on 타이머가 살아있다', () {
      final t = RunningTimer.fanTimerFrom([
        cmd('fan_off', 'rejected', '2026-08-14T11:55:00Z'),
        cmd('fan_on', 'acked', '2026-08-14T11:50:00Z', durationMs: 1800000),
      ], now);
      expect(t, isNotNull);
    });

    test('발행 직후(pending)도 타이머로 본다 — 칩이 바로 떠야 한다', () {
      final t = RunningTimer.fanTimerFrom(
        [cmd('fan_on', 'pending', '2026-08-14T11:59:00Z', durationMs: 600000)],
        now,
      );
      expect(t, isNotNull);
    });

    test('duration 없는 fan_on(그냥 켜기) → null', () {
      final t = RunningTimer.fanTimerFrom(
        [cmd('fan_on', 'acked', '2026-08-14T11:50:00Z')],
        now,
      );
      expect(t, isNull);
    });

    test('만료된 타이머 → null', () {
      final t = RunningTimer.fanTimerFrom(
        [cmd('fan_on', 'acked', '2026-08-14T10:00:00Z', durationMs: 600000)],
        now,
      );
      expect(t, isNull);
    });

    test('빈 목록 → null', () {
      expect(RunningTimer.fanTimerFrom(const [], now), isNull);
    });
  });
}
