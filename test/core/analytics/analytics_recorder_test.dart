import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_recorder.dart';
import 'package:vivnanaut/core/analytics/clarity_setup.dart';

class FakeAnalyticsSdk implements AnalyticsSdk {
  final events = <String>[];
  final screens = <String>[];
  final sessions = <void Function()>[];
  final calls = <String>[];
  int starts = 0;
  int pauses = 0;
  bool fail = false;
  @override
  bool initialize(void Function() onSession) {
    calls.add('initialize');
    starts++;
    return true;
  }

  @override
  bool pause() {
    calls.add('pause');
    pauses++;
    return true;
  }

  @override
  bool resume() {
    calls.add('resume');
    return true;
  }

  @override
  bool startNewSession(void Function() onSession) {
    calls.add('rotate');
    sessions.add(onSession);
    return true;
  }

  @override
  bool setScreen(String screen) {
    calls.add('screen:$screen');
    screens.add(screen);
    return true;
  }

  @override
  bool sendEvent(String event) {
    if (fail) throw StateError('sdk');
    events.add(event);
    return true;
  }

  @override
  bool setTag(String key, String value) => true;
  @override
  bool setConsent(bool granted) {
    calls.add('consent:$granted');
    return true;
  }
}

void main() {
  late FakeAnalyticsSdk sdk;
  late AnalyticsRecorder recorder;
  void enter(
      {bool consent = true,
      String? account = 'local-a',
      String? screen = 'home',
      bool enabled = true,
      bool foreground = true}) {
    recorder.synchronize(
        enabled: enabled,
        consent: consent,
        accountId: account,
        screenName: screen,
        foreground: foreground);
  }

  setUp(() {
    sdk = FakeAnalyticsSdk();
    recorder = AnalyticsRecorder(sdk: sdk);
  });
  test(
      'inert before an opted in allowed boundary; initialization is not readiness',
      () {
    recorder.record(AnalyticsEvent.liveRequested);
    enter(consent: false);
    enter(enabled: false);
    enter(screen: null);
    expect(sdk.starts, 0);
    enter();
    recorder.record(AnalyticsEvent.liveRequested);
    expect(sdk.events, isEmpty);
    sdk.sessions.last();
    recorder.record(AnalyticsEvent.liveRequested);
    expect(sdk.events, ['live_requested']);
  });
  test(
      'features deduplicate in session; allowed navigation preserves async work',
      () {
    enter();
    sdk.sessions.last();
    final epoch = recorder.epoch;
    recorder.featureUsed(AnalyticsFeature.clips);
    enter(screen: 'clip_player');
    recorder.featureUsed(AnalyticsFeature.clips);
    recorder.record(AnalyticsEvent.clipPlaying, epoch: epoch);
    expect(recorder.epoch, epoch);
    expect(sdk.events, ['feature_clips_used', 'clip_playing']);
  });
  test(
      'initialization queues only the safe screen and paused consent before capture',
      () {
    enter();
    expect(sdk.calls, [
      'screen:home',
      'pause',
      'consent:true',
      'initialize',
      'rotate',
      'resume'
    ]);
    expect(sdk.events, isEmpty);
  });
  test('withdrawal rejects old outcomes and late SDK callback', () {
    enter();
    final oldCallback = sdk.sessions.last;
    oldCallback();
    final epoch = recorder.epoch;
    enter(consent: false);
    oldCallback();
    recorder.record(AnalyticsEvent.clipPlaying, epoch: epoch);
    recorder.record(AnalyticsEvent.liveRequested);
    expect(sdk.events, isEmpty);
    expect(sdk.pauses, greaterThan(0));
  });
  test('account changes and background create a new session before new events',
      () {
    enter();
    sdk.sessions.last();
    final oldEpoch = recorder.epoch;
    enter(account: 'local-b');
    recorder.record(AnalyticsEvent.clipPlaying, epoch: oldEpoch);
    expect(sdk.events, isEmpty);
    sdk.sessions.last();
    recorder.featureUsed(AnalyticsFeature.live);
    enter(account: 'local-b', foreground: false);
    recorder.record(AnalyticsEvent.liveRequested);
    enter(account: 'local-b');
    sdk.sessions.last();
    recorder.featureUsed(AnalyticsFeature.live);
    expect(sdk.events, ['feature_live_used', 'feature_live_used']);
  });
  test('SDK errors never escape to business actions', () {
    enter();
    sdk.sessions.last();
    sdk.fail = true;
    expect(
        () => recorder.record(AnalyticsEvent.controlAccepted), returnsNormally);
  });
  test('automatic SDK session rotation invalidates old async results', () {
    enter();
    final sessionCallback = sdk.sessions.last;
    sessionCallback();
    final oldEpoch = recorder.epoch;
    recorder.featureUsed(AnalyticsFeature.live);
    sessionCallback();
    recorder.record(AnalyticsEvent.liveConnected, epoch: oldEpoch);
    recorder.featureUsed(AnalyticsFeature.live);
    expect(sdk.events, ['feature_live_used', 'feature_live_used']);
  });
  test('configuration remains off unless deployment, platform and ID are valid',
      () {
    expect(const ClarityRuntimeConfig().canCollect, isFalse);
    expect(
        const ClarityRuntimeConfig(enabled: true, mobile: true, release: true)
            .canCollect,
        isTrue);
    expect(
        const ClarityRuntimeConfig(
                enabled: true, mobile: true, projectId: kClarityProjectId)
            .canCollect,
        isFalse);
    expect(
        const ClarityRuntimeConfig(
                enabled: true, mobile: true, projectId: 'qatest123')
            .canCollect,
        isTrue);
    expect(
        const ClarityRuntimeConfig(enabled: true, projectId: 'qatest123')
            .canCollect,
        isFalse);
  });
}
