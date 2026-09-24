import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/live_view_session.dart';

void main() {
  late DateTime now;
  LiveViewSession open({bool? online = true}) => LiveViewSession(
        viewId: 'v1',
        cameraId: 'cam',
        firmwareVer: '1.2.0',
        network: 'wifi',
        cameraOnline: online,
        clock: () => now,
      );
  void tick(int ms) => now = now.add(Duration(milliseconds: ms));

  setUp(() => now = DateTime.utc(2026, 9, 25, 12));

  test('성공 흐름: 연결 → 영상 — 첫 영상 시각과 상태별 시간', () {
    final s = open();
    s.onAttempt();
    s.onPhase(LiveViewBucket.connecting);
    tick(2500);
    s.onPhase(LiveViewBucket.video);
    tick(10000);
    final r = s.finish(LiveViewEnd.closed)!;

    expect(r.firstVideoMs, 2500);
    expect(r.durationMs, 12500);
    expect(r.msConnecting, 2500);
    expect(r.msVideo, 10000);
    expect(r.attempts, 1);
    expect(r.endReason, LiveViewEnd.closed);
  });

  test('실패·복구·정지 구간과 진입 횟수, 재연결 사유를 센다', () {
    final s = open();
    s.onAttempt();
    s.onPhase(LiveViewBucket.connecting);
    tick(1000);
    s.onPhase(LiveViewBucket.recovering);
    tick(3000);
    s.onRestart('timer');
    s.onAttempt();
    s.onPhase(LiveViewBucket.connecting);
    tick(1000);
    s.onPhase(LiveViewBucket.failed);
    tick(4000);
    s.onManualRetry();
    s.onRestart('manual');
    s.onAttempt();
    s.onPhase(LiveViewBucket.connecting);
    tick(500);
    s.onPhase(LiveViewBucket.video);
    tick(2000);
    s.onPhase(LiveViewBucket.stalled);
    tick(1000);
    s.onPhase(LiveViewBucket.video);
    tick(1000);
    s.onPhase(LiveViewBucket.stalled);
    tick(500);
    final r = s.finish(LiveViewEnd.background)!;

    expect(r.firstVideoMs, 9500);
    expect(r.msConnecting, 2500);
    expect(r.msRecovering, 3000);
    expect(r.msFailed, 4000);
    expect(r.msVideo, 3000);
    expect(r.msStalled, 1500);
    expect(r.durationMs, 14000);
    expect(r.stallCount, 2);
    expect(r.failedCount, 1);
    expect(r.manualRetries, 1);
    expect(r.attempts, 3);
    expect(r.restarts, {'timer': 1, 'manual': 1});
  });

  test('같은 상태 재통지는 진입 횟수를 늘리지 않는다', () {
    final s = open();
    s.onPhase(LiveViewBucket.failed);
    tick(100);
    s.onPhase(LiveViewBucket.failed);
    tick(100);
    expect(s.finish(LiveViewEnd.closed)!.failedCount, 1);
  });

  test('영상을 못 보면 firstVideoMs는 null', () {
    final s = open(online: false);
    s.onPhase(LiveViewBucket.connecting);
    tick(30000);
    final r = s.finish(LiveViewEnd.closed)!;
    expect(r.firstVideoMs, isNull);
    expect(r.cameraOnline, isFalse);
  });

  test('fillEnv는 비어 있던 값만 채운다', () {
    final s = LiveViewSession(viewId: 'v', cameraId: 'c', network: 'wifi');
    s.fillEnv(firmwareVer: '1.3.0', network: 'mobile', cameraOnline: true);
    final r = s.finish(LiveViewEnd.closed)!;
    expect(r.firmwareVer, '1.3.0');
    expect(r.network, 'wifi');
    expect(r.cameraOnline, isTrue);
  });

  test('finish는 한 번만 결과를 낸다', () {
    final s = open();
    expect(s.finish(LiveViewEnd.closed), isNotNull);
    expect(s.finish(LiveViewEnd.closed), isNull);
    // 끝난 뒤 들어온 통지는 무시한다.
    s.onPhase(LiveViewBucket.video);
    s.onRestart('network');
  });

  test('toRow — DB 컬럼 이름·null 생략·시작 시각 UTC', () {
    final s = open();
    s.onPhase(LiveViewBucket.connecting);
    tick(1000);
    s.onRestart('network');
    final row = s.finish(LiveViewEnd.closed)!
        .toRow(appVersion: '0.135.0+349', platform: 'ios');
    expect(row['view_id'], 'v1');
    expect(row['camera_id'], 'cam');
    expect(row['started_at'], '2026-09-25T12:00:00.000Z');
    expect(row['end_reason'], 'closed');
    expect(row['duration_ms'], 1000);
    expect(row['restarts'], {'network': 1});
    expect(row['firmware_ver'], '1.2.0');
    expect(row.containsKey('first_video_ms'), isFalse);
    expect(row.containsKey('user_id'), isFalse);
  });
}
