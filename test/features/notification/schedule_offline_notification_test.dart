import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/schedule_last_run.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';

/// terra-server#16 — 예약 시각 기기 오프라인 실패(2026-10-01).
/// EasyLocalization을 세우지 않아 `.tr()`은 키를 돌려준다(이 레포 관례).
AppNotification _n(Map<String, Object?> data,
        {String kind = 'device.action.failed'}) =>
    AppNotification.fromJson({
      'id': 'n',
      'user_id': 'u',
      'kind': kind,
      'title': '서버 제목',
      'body': '서버 본문',
      'data': data,
    });

void main() {
  test('device_offline이면 앱 문구로 바꾼다(data 바로 아래)', () {
    final n = _n({'result': 'device_offline', 'device_name': '거실 사육장'});
    expect(n.isScheduleDeviceOffline, isTrue);
    expect(n.displayTitle, 'schedule_offline_title_named');
    expect(n.displayBody, isNot('서버 본문'));
  });

  test('payload 아래에 있어도 알아본다, 기기 이름 없으면 기본 제목', () {
    final n = _n({
      'payload': <String, Object?>{'result': 'device_offline', 'action': 'mist'}
    });
    expect(n.isScheduleDeviceOffline, isTrue);
    expect(n.displayTitle, 'schedule_offline_title');
  });

  test('다른 실패·다른 종류는 서버 문구 그대로', () {
    expect(_n({'result': 'no_ack'}).displayTitle, '서버 제목');
    expect(
        _n({'result': 'device_offline'}, kind: 'device.action.skipped')
            .displayBody,
        '서버 본문');
  });

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
