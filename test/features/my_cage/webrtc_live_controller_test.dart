// 라이브 연결 안정성(2026-09-22) — 가짜 피어·시그널링·렌더러로 재연결 세대
// 분리, 백그라운드 일시정지, 네트워크 전환, 오프라인 대기, 첫 프레임 판정을
// 검증한다(native WebRTC 없이).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivanaut/features/my_cage/data/webrtc_signaling_repository.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';

const _cam = 'cam-1';

class _FakePc extends Fake implements RTCPeerConnection {
  _FakePc(this.index);
  final int index;
  final added = <String?>[];
  bool closed = false;
  int frames = 0;
  RTCPeerConnectionState? _state;

  @override
  Function(RTCTrackEvent event)? onTrack;
  @override
  Function(RTCIceCandidate candidate)? onIceCandidate;
  @override
  Function(RTCPeerConnectionState state)? onConnectionState;
  @override
  Function(RTCIceGatheringState state)? onIceGatheringState;

  void emit(RTCPeerConnectionState s) {
    _state = s;
    onConnectionState?.call(s);
  }

  @override
  RTCPeerConnectionState? get connectionState => _state;
  @override
  RTCIceGatheringState? get iceGatheringState =>
      RTCIceGatheringState.RTCIceGatheringStateComplete;
  @override
  Future<RTCRtpTransceiver> addTransceiver(
          {MediaStreamTrack? track,
          RTCRtpMediaType? kind,
          RTCRtpTransceiverInit? init}) async =>
      _FakeTransceiver();
  @override
  Future<RTCSessionDescription> createOffer(
          [Map<String, dynamic>? constraints]) async =>
      RTCSessionDescription('offer', 'offer');
  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}
  @override
  Future<RTCSessionDescription?> getLocalDescription() async =>
      RTCSessionDescription('offer-$index', 'offer');
  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {}
  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async =>
      added.add(candidate.candidate);
  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async => [
        StatsReport('in', 'inbound-rtp', 0,
            {'kind': 'video', 'framesDecoded': frames}),
      ];
  @override
  Future<void> close() async {
    closed = true;
    _state = RTCPeerConnectionState.RTCPeerConnectionStateClosed;
  }
}

class _FakeTransceiver extends Fake implements RTCRtpTransceiver {}

class _FakeRenderer extends RTCVideoRenderer {
  @override
  Future<void> initialize() async {}
  @override
  set srcObject(MediaStream? stream) {}
  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

class _FakeSignaling extends Fake implements WebRtcSignalingRepository {
  var _offers = 0;
  final closedSessions = <String>[];
  final polls = <String>[];

  /// 세션별 대기 중인 long-poll — 테스트가 후보를 넣어 끝낸다.
  final pollWaits =
      <String, Completer<({List<Map<String, dynamic>> candidates, int nextIndex})>>{};

  /// 다음 offer 응답을 테스트가 잡아 두고 싶을 때.
  Completer<void>? holdOffer;

  @override
  Future<({String sessionId, String answerSdp})> sendOffer(
      String cameraUuid, String sdp) async {
    final id = 's${++_offers}';
    final hold = holdOffer;
    if (hold != null) await hold.future;
    return (sessionId: id, answerSdp: 'answer');
  }

  @override
  Future<({List<Map<String, dynamic>> candidates, int nextIndex})>
      pollCandidates(String cameraUuid, String sessionId, int sinceIndex) {
    polls.add(sessionId);
    return (pollWaits[sessionId] = Completer()).future;
  }

  @override
  Future<void> sendIceCandidate(String cameraUuid, String sessionId,
      Map<String, dynamic> candidateJson) async {}

  @override
  Future<void> closeSession(String cameraUuid, String sessionId) async =>
      closedSessions.add(sessionId);
}

TerraCamera _camera({required bool online}) => TerraCamera(
    id: _cam,
    cameraId: 'p4cam',
    name: 'cam',
    isOnline: online,
    createdAt: DateTime(2026, 9, 22));

class _Harness {
  final pcs = <_FakePc>[];
  final signaling = _FakeSignaling();
  final network = StreamController<String>();
  final cameras = StreamController<List<TerraCamera>>();
  late final ProviderContainer container;

  _Harness() {
    container = ProviderContainer(overrides: [
      webrtcSignalingRepositoryProvider.overrideWithValue(signaling),
      webrtcConfigProvider.overrideWith((ref) async => <String, dynamic>{}),
      webrtcPeerConnectionFactoryProvider.overrideWithValue((_) async {
        final pc = _FakePc(pcs.length + 1);
        pcs.add(pc);
        return pc;
      }),
      webrtcRendererFactoryProvider
          .overrideWithValue(() async => _FakeRenderer()),
      webrtcNetworkSignalProvider.overrideWith((ref) => network.stream),
      camerasProvider.overrideWith((ref) => cameras.stream),
    ]);
    container.listen(webrtcLiveControllerProvider(_cam), (_, __) {});
    container.listen(camerasProvider, (_, __) {});
  }

  WebRtcLiveState get state => container.read(webrtcLiveControllerProvider(_cam));
  _FakePc get pc => pcs.last;
  RTCVideoRenderer get renderer => state.renderer!;

  Future<void> dispose() async {
    container.dispose();
    unawaited(network.close());
    unawaited(cameras.close());
  }
}

/// ICE 수집 대기(2초)·offer 왕복을 흘려보낸다.
Future<void> _settleConnect(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(kWebRtcIceGatherWait + const Duration(milliseconds: 50));
  await tester.pump();
}

void main() {
  testWidgets('재연결 후 이전 세션의 ICE 후보가 새 피어에 섞이지 않는다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    expect(h.pcs, hasLength(1));
    expect(h.signaling.polls, ['s1']);
    final old = h.pc;

    old.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.failed);
    await tester.pump(const Duration(seconds: 3)); // 백오프 3초
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    expect(old.closed, isTrue);

    // 뒤늦게 끝난 이전 세션 long-poll — 후보는 어디에도 들어가면 안 되고,
    // 이전 세션 폴링은 거기서 멈춰야 한다.
    h.signaling.pollWaits['s1']!.complete((
      candidates: [
        {'candidate': 'old-cand', 'sdpMid': '0', 'sdpMLineIndex': 0}
      ],
      nextIndex: 1
    ));
    await tester.pump();
    await tester.pump();
    expect(h.pc.added, isEmpty);
    expect(old.added, isEmpty);
    expect(h.signaling.polls.where((s) => s == 's1'), hasLength(1));
    await h.dispose();
  });

  testWidgets('offer 응답 전에 새 세대로 넘어가면 그 세션을 닫는다', (tester) async {
    final h = _Harness();
    h.signaling.holdOffer = Completer();
    await _settleConnect(tester);
    // 가짜 시계에선 retry()를 await하면 ICE 대기 타이머가 안 흘러 멈춘다.
    unawaited(h.container
        .read(webrtcLiveControllerProvider(_cam).notifier)
        .retry());
    await tester.pump();
    final hold = h.signaling.holdOffer!;
    h.signaling.holdOffer = null;
    hold.complete();
    await _settleConnect(tester);
    // s1(첫 세대)은 아무도 안 쓰니 서버에 닫기를 보냈다.
    expect(h.signaling.closedSessions, contains('s1'));
    await h.dispose();
  });

  testWidgets('ICE 연결만으로는 LIVE가 아니다 — 첫 프레임에 streaming', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    expect(h.state.phase, WebRtcLivePhase.waitingVideo);
    h.renderer.onFirstFrameRendered!();
    expect(h.state.phase, WebRtcLivePhase.streaming);
    await h.dispose();
  });

  testWidgets('첫 프레임 콜백이 없어도 디코딩 통계로 streaming', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.pc.frames = 12;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(h.state.phase, WebRtcLivePhase.streaming);
    await h.dispose();
  });

  testWidgets('연결됐는데 30초간 영상이 없으면 다시 붙인다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    await tester.pump(kWebRtcFirstFrameTimeout);
    await tester.pump();
    expect(h.state.phase, WebRtcLivePhase.failed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('재생 중 프레임이 15초간 멈추면 다시 붙인다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.frames = 5;
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.renderer.onFirstFrameRendered!();
    expect(h.state.phase, WebRtcLivePhase.streaming);
    // 프레임이 늘어나는 동안은 멀쩡하다.
    for (var i = 0; i < 4; i++) {
      h.pc.frames += 10;
      await tester.pump(kWebRtcStallCheckInterval);
      await tester.pump();
    }
    expect(h.state.phase, WebRtcLivePhase.streaming);
    // 멈춤: 같은 값이 3회 연속이면 실패(그다음 주기엔 이미 재연결 중이다).
    for (var i = 0; i < kWebRtcStallChecks; i++) {
      await tester.pump(kWebRtcStallCheckInterval);
      await tester.pump();
    }
    expect(h.state.phase, WebRtcLivePhase.failed);
    await h.dispose();
  });

  testWidgets('백그라운드면 연결을 내리고, 복귀하면 즉시 다시 붙인다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    final first = h.pc;

    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    expect(first.closed, isTrue);
    expect(h.signaling.closedSessions, contains('s1'));
    // 백그라운드 동안은 재연결하지 않는다.
    await tester.pump(const Duration(minutes: 2));
    expect(h.pcs, hasLength(1));

    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('Wi-Fi→LTE 전환이면 백오프를 기다리지 않고 즉시 다시 붙인다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    expect(h.pcs, hasLength(1));

    h.network.add('mobile');
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    expect(h.pcs.first.closed, isTrue);

    // 연결이 완전히 끊긴 순간(none)에는 헛시도하지 않는다.
    h.network.add('none');
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('오프라인 카메라는 자동 재연결을 멈추고, 온라인이 되면 곧바로 붙는다',
      (tester) async {
    final h = _Harness();
    h.cameras.add([_camera(online: false)]);
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(minutes: 3));
    expect(h.pcs, hasLength(1), reason: '꺼진 카메라에 offer를 계속 보내지 않는다');

    h.cameras.add([_camera(online: true)]);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });
}
