import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/running_timer.dart';

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

  group('RunningTimer.fromJson', () {
    test('테이블 컬럼 매핑', () {
      final t = RunningTimer.fromJson({
        'id': 't1',
        'device_id': 'd1',
        'actuator': 'fan',
        'duration_minutes': 30,
        'ends_at': '2026-08-05T12:18:20Z',
      });
      expect(t.deviceId, 'd1');
      expect(t.actuatorLabelKey, 'module_actuator_fan');
      expect(t.durationMinutes, 30);
    });

    test('알 수 없는 actuator도 죽지 않는다', () {
      final t = RunningTimer.fromJson({
        'id': 't1',
        'device_id': 'd1',
        'actuator': 'mystery',
        'duration_minutes': 5,
        'ends_at': '2026-08-05T12:00:00Z',
      });
      expect(t.actuatorLabelKey, 'module_actuator_unknown');
    });
  });
}
