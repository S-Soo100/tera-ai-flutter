import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/shared/providers/screen_wake_lock_provider.dart';
import 'package:vivanaut/shared/widgets/keep_screen_on.dart';

/// 초기화만 보고하는 가짜 비디오 플랫폼(길이 60초).
class _FakeVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>(
        onListen: () => events.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 60),
            size: const Size(1920, 1080))),
        onCancel: () async {});
    return events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Widget buildView(int playerId) => const SizedBox();
}

void main() {
  late List<bool> calls;
  late ScreenWakeLock lock;

  setUp(() {
    calls = [];
    lock = ScreenWakeLock(toggle: (enable) async => calls.add(enable));
  });

  Widget scope(Widget child) => ProviderScope(
        overrides: [screenWakeLockProvider.overrideWithValue(lock)],
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      );

  Widget host(
          {required bool visible, bool active = true, bool second = false}) =>
      scope(Column(children: [
        TickerMode(
          enabled: visible,
          child: KeepScreenOn(active: active, child: const SizedBox()),
        ),
        if (second) const KeepScreenOn(child: SizedBox()),
      ]));

  testWidgets('보이면 켜고 사라지면 끈다', (tester) async {
    await tester.pumpWidget(host(visible: true));
    expect(calls, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(calls, [true, false]);
  });

  testWidgets('다른 탭·덮인 화면(TickerMode 꺼짐)이면 놓는다', (tester) async {
    await tester.pumpWidget(host(visible: false));
    expect(calls, isEmpty);
    await tester.pumpWidget(host(visible: true));
    expect(calls, [true]);
    await tester.pumpWidget(host(visible: false));
    expect(calls, [true, false]);
  });

  testWidgets('active가 꺼지면 놓고 켜지면 다시 잡는다', (tester) async {
    await tester.pumpWidget(host(visible: true, active: false));
    expect(calls, isEmpty);
    await tester.pumpWidget(host(visible: true));
    expect(calls, [true]);
    await tester.pumpWidget(host(visible: true, active: false));
    expect(calls, [true, false]);
  });

  testWidgets('여러 화면이 잡으면 마지막이 놓을 때만 끈다', (tester) async {
    await tester.pumpWidget(host(visible: true, second: true));
    expect(calls, [true]);
    await tester.pumpWidget(host(visible: false, second: true));
    expect(calls, [true], reason: '두 번째가 아직 잡고 있다');
    await tester.pumpWidget(host(visible: false));
    expect(calls, [true, false]);
  });

  test('켜기가 실패하면 다음 잡기에서 다시 켠다', () async {
    var fail = true;
    final log = <bool>[];
    final l = ScreenWakeLock(toggle: (enable) async {
      log.add(enable);
      if (fail) throw Exception('no activity');
    });
    l.acquire();
    await pumpEventQueue();
    fail = false;
    l.acquire();
    await pumpEventQueue();
    expect(log, [true, true]);
    l.acquire();
    expect(log, [true, true], reason: '성공한 뒤엔 다시 보내지 않는다');
  });

  test('앱 복귀(reapply)는 잡고 있을 때만 다시 건다', () async {
    lock.reapply();
    expect(calls, isEmpty);
    lock.acquire();
    lock.reapply();
    expect(calls, [true, true]);
    lock.release();
    lock.reapply();
    expect(calls, [true, true, false]);
  });

  test('라이브는 실패·시청 제한이면 화면을 놓는다', () {
    final keep = {
      for (final p in WebRtcLivePhase.values) p: p.keepsScreenOn,
    };
    expect(keep[WebRtcLivePhase.failed], isFalse);
    expect(keep[WebRtcLivePhase.limited], isFalse);
    expect(keep[WebRtcLivePhase.streaming], isTrue);
    expect(keep[WebRtcLivePhase.connectingIce], isTrue);
    expect(keep[WebRtcLivePhase.recovering], isTrue);
  });

  testWidgets('영상은 재생 중에만 화면을 켠다', (tester) async {
    VideoPlayerPlatform.instance = _FakeVideoPlatform();
    final c = VideoPlayerController.networkUrl(Uri.parse('https://x/v.mp4'));
    await c.initialize();
    await tester.pumpWidget(scope(
        KeepScreenOnWhilePlaying(controller: c, child: const SizedBox())));
    expect(calls, isEmpty);
    await c.play();
    await tester.pump();
    expect(calls, [true]);
    await c.pause();
    await tester.pump();
    expect(calls, [true, false]);
    await tester.pumpWidget(const SizedBox());
    await c.dispose();
  });
}
