import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_recorder.dart';
import 'package:vivnanaut/features/my_cage/presentation/pairing_analytics_observer.dart';

class _Analytics extends AnalyticsRecorder {
  final events = <AnalyticsEvent>[];
  @override
  int epoch = 1;
  @override
  void record(AnalyticsEvent event, {int? epoch}) {
    if (epoch == this.epoch) events.add(event);
  }
}

void main() {
  test('권한 화면 복귀 후 사용자 선택·제출은 현재 epoch로 결과를 기록한다', () {
    final analytics = _Analytics();
    final observer = PairingAnalyticsObserver(analytics);
    final scan = observer.startAttempt();
    analytics.epoch++;
    analytics.events.clear();
    observer.deviceSelected();
    observer.wifiSubmitted();
    observer.wifiSucceeded(scan.attempt);
    expect(analytics.events, [
      AnalyticsEvent.pairDeviceSelected,
      AnalyticsEvent.pairWifiSubmitted,
      AnalyticsEvent.pairWifiSucceeded
    ]);
  });

  test('SDK epoch가 같아도 retry 이전 BLE 콜백과 비동기 오류는 버린다', () {
    final analytics = _Analytics();
    final observer = PairingAnalyticsObserver(analytics);
    final old = observer.startAttempt();
    final current = observer.startAttempt();
    analytics.events.clear();
    observer.wifiSucceeded(old.attempt);
    observer.bleFailed(old.attempt);
    observer.failed(old);
    expect(analytics.events, isEmpty);
    observer.wifiSubmitted();
    observer.wifiSucceeded(current.attempt);
    observer.wifiSucceeded(current.attempt);
    expect(analytics.events,
        [AnalyticsEvent.pairWifiSubmitted, AnalyticsEvent.pairWifiSucceeded]);
  });

  test('같은 attempt에서 새 사용자 동작 전의 늦은 오류는 제외한다', () {
    final analytics = _Analytics();
    final observer = PairingAnalyticsObserver(analytics);
    observer.startAttempt();
    final oldAction = observer.deviceSelected();
    final submission = observer.wifiSubmitted();
    analytics.events.clear();
    observer.failed(oldAction);
    expect(analytics.events, isEmpty);
    observer.failed(submission);
    observer.failed(submission);
    expect(analytics.events, [AnalyticsEvent.pairFailed]);
  });

  test('새 사용자 행동 없는 세션 변경 뒤에는 이전 WIFI 결과를 버린다', () {
    final analytics = _Analytics();
    final observer = PairingAnalyticsObserver(analytics);
    final ticket = observer.startAttempt();
    observer.wifiSubmitted();
    analytics.events.clear();
    analytics.epoch++;
    observer.wifiSucceeded(ticket.attempt);
    expect(analytics.events, isEmpty);
  });
}
