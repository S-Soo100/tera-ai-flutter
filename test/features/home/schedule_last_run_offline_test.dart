import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/schedule_last_run.dart';

/// terra-server#16 — 예약 시각 기기 오프라인 실패(2026-10-01).
/// 푸시·알림 문구는 DB 트리거가 만든다(20261001 마이그레이션).
void main() {
  test('실행 기록: skipped+device_offline은 오프라인 건너뜀', () {
    final run = latestScheduleRuns([
      {
        'source_id': 's1',
        'status': 'skipped',
        'result': 'device_offline',
        'issued_at': '2026-10-01T00:00:00Z'
      }
    ])['s1']!;
    expect(run.failureKey, 'schedule_run_device_offline');
    expect(run.pending, isFalse);
  });
}
