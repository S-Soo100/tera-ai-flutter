import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/core/analytics/analytics_recorder.dart';
import 'package:vivnanaut/features/my_cage/presentation/camera_live_fullscreen_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/webrtc_live_controller.dart';

class _Analytics extends AnalyticsRecorder {
  final events = <AnalyticsEvent>[];
  @override
  void record(AnalyticsEvent event, {int? epoch}) => events.add(event);
}

class _Live extends WebRtcLiveController {
  _Live(super.ref, super.cameraUuid);
  void emit(WebRtcLivePhase phase) {
    state = WebRtcLiveState(
      phase: phase,
      renderer: phase == WebRtcLivePhase.streaming ? RTCVideoRenderer() : null,
    );
  }
}

void main() {
  testWidgets('라이브 진입 요청과 연결 상태를 분리하고 재시도·리빌드로 중복하지 않는다', (tester) async {
    final analytics = _Analytics();
    late _Live live;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          analyticsRecorderProvider.overrideWithValue(analytics),
          camerasProvider.overrideWith((ref) => Stream.value(const [])),
          webrtcLiveControllerProvider
              .overrideWith((ref, id) => live = _Live(ref, id)),
        ],
        child: const MaterialApp(
            home: CameraLiveFullscreenScreen(cameraId: 'private-camera'))));
    await tester.pump();
    expect(analytics.events, [AnalyticsEvent.liveRequested]);
    live.emit(WebRtcLivePhase.failed);
    await tester.pump();
    live.emit(WebRtcLivePhase.failed);
    await tester.pump();
    expect(analytics.events,
        [AnalyticsEvent.liveRequested, AnalyticsEvent.liveFailed]);
    live.emit(WebRtcLivePhase.streaming);
    await tester.pump();
    live.emit(WebRtcLivePhase.streaming);
    await tester.pump();
    expect(analytics.events, [
      AnalyticsEvent.liveRequested,
      AnalyticsEvent.liveFailed,
      AnalyticsEvent.liveConnected
    ]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
