import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/clarity_session_monitor.dart';
import 'package:vivnanaut/core/analytics/clarity_sdk.dart';
import 'package:vivnanaut/core/analytics/clarity_setup.dart';

void main() {
  for (final pause in [true, false]) {
    testWidgets(
        'adapter ${pause ? 'pause' : 'unbind'} cancels session confirmation',
        (tester) async {
      String? url;
      void Function()? callback;
      var ready = 0;
      final monitor = ClaritySessionMonitor(
          readSessionUrl: () => url,
          requestSession: (next) {
            callback = next;
            return true;
          });
      final sdk = ClarityAnalyticsSdk(const ClarityRuntimeConfig(),
          sessionMonitor: monitor, tagWriter: (_, __) => true);
      sdk.startNewSession(() => ready++);
      if (pause) {
        sdk.pause();
      } else {
        sdk.unbind();
      }
      url = 'session-after-stop';
      callback!();
      await tester.pump(const Duration(seconds: 31));
      expect(ready, 0);
    });
  }
  testWidgets('adapter tags confirmed sessions with the configured environment',
      (tester) async {
    String? url;
    var ready = 0;
    final tags = <String, String>{};
    final sdk = ClarityAnalyticsSdk(
      const ClarityRuntimeConfig(
          enabled: true, mobile: true, projectId: 'qatest123'),
      sessionMonitor: ClaritySessionMonitor(
          readSessionUrl: () => url, requestSession: (_) => true),
      tagWriter: (key, value) {
        tags[key] = value;
        return true;
      },
    );
    sdk.startNewSession(() => ready++);
    expect(tags, isEmpty);
    url = 'confirmed';
    await tester.pump(const Duration(milliseconds: 500));
    expect(tags, {'environment': 'qa'});
    expect(ready, 1);
    expect(const ClarityRuntimeConfig(release: true).environmentName,
        'production');
    sdk.unbind();
  });
  testWidgets('missing callback is recovered by a changed session URL once',
      (tester) async {
    String? url = 'old-session';
    void Function()? sdkCallback;
    var ready = 0;
    final monitor = ClaritySessionMonitor(
      readSessionUrl: () => url,
      requestSession: (callback) {
        sdkCallback = callback;
        return true;
      },
    );
    expect(monitor.start(() => ready++), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(ready, 0);
    url = 'new-session';
    await tester.pump(const Duration(milliseconds: 500));
    expect(ready, 1);
    sdkCallback!();
    await tester.pump(const Duration(seconds: 30));
    expect(ready, 1);
    monitor.cancel();
  });

  testWidgets('unchanged URL times out and ignores a late callback',
      (tester) async {
    void Function()? sdkCallback;
    var reads = 0;
    var ready = 0;
    final monitor = ClaritySessionMonitor(
      readSessionUrl: () {
        reads++;
        return 'old-session';
      },
      requestSession: (callback) {
        sdkCallback = callback;
        return true;
      },
    );
    monitor.start(() => ready++);
    await tester.pump(const Duration(seconds: 30));
    expect(ready, 0);
    final readsAtTimeout = reads;
    sdkCallback!();
    await tester.pump(const Duration(seconds: 30));
    expect(reads, readsAtTimeout);
    expect(ready, 0);
  });

  testWidgets('pause/unbind cancellation rejects late URL and native callback',
      (tester) async {
    String? url;
    void Function()? sdkCallback;
    var ready = 0;
    final monitor = ClaritySessionMonitor(
      readSessionUrl: () => url,
      requestSession: (callback) {
        sdkCallback = callback;
        return true;
      },
    );
    monitor.start(() => ready++);
    monitor.cancel();
    url = 'new-session';
    sdkCallback!();
    await tester.pump(const Duration(seconds: 31));
    expect(ready, 0);
  });

  testWidgets('real callback cancels polling and errors never open the gate',
      (tester) async {
    void Function()? sdkCallback;
    var reads = 0;
    var ready = 0;
    final monitor = ClaritySessionMonitor(
      readSessionUrl: () {
        reads++;
        return null;
      },
      requestSession: (callback) {
        sdkCallback = callback;
        return true;
      },
    );
    monitor.start(() => ready++);
    sdkCallback!();
    await tester.pump(const Duration(seconds: 30));
    expect(ready, 1);
    expect(reads, 1);
    final failure = ClaritySessionMonitor(
      readSessionUrl: () => throw StateError('SDK unavailable'),
      requestSession: (_) => true,
    );
    expect(failure.start(() => ready++), isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(ready, 1);
  });
}
