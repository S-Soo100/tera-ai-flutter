// 라이브 연결 안정성(2026-09-22) — 가짜 피어·시그널링·렌더러로 재연결 세대
// 분리, 백그라운드 일시정지, 네트워크 전환, 오프라인 대기, 첫 프레임 판정을
// 검증한다(native WebRTC 없이).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivanaut/features/my_cage/data/webrtc_signaling_repository.dart';
import 'package:vivanaut/features/my_cage/data/camera_exceptions.dart';
import 'package:vivanaut/features/my_cage/domain/live_view_session.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/domain/webrtc_connect_log.dart';
import 'package:vivanaut/features/my_cage/domain/webrtc_diag.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_diag_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';

const _cam = 'cam-1';

class _FakePc extends Fake implements RTCPeerConnection {
  _FakePc(this.index);
  final int index;
  final added = <String?>[];
  bool closed = false;
  int frames = 0;

  /// 수신 누적 바이트·손실 패킷. null이면 통계에 필드를 넣지 않는다.
  int? bytes;
  int? lost;

  /// true면 getStats가 실패한다(통계 없음).
  bool statsBroken = false;
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
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    if (statsBroken) throw StateError('no stats');
    return [
        StatsReport('in', 'inbound-rtp', 0, {
          'kind': 'video',
          'framesDecoded': frames,
          if (bytes != null) 'bytesReceived': bytes,
          if (lost != null) 'packetsLost': lost,
        }),
        StatsReport('t', 'transport', 0, {'selectedCandidatePairId': 'p'}),
        StatsReport('p', 'candidate-pair', 0,
            {'localCandidateId': 'l', 'remoteCandidateId': 'r'}),
        StatsReport('l', 'local-candidate', 0, {'candidateType': 'srflx'}),
        StatsReport('r', 'remote-candidate', 0, {'candidateType': 'host'}),
      ];
  }
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

  /// 남은 504 응답 횟수.
  int unresponsive = 0;

  /// 다음 offer를 이 예외로 실패시킨다(1회).
  Object? failOfferWith;

  @override
  Future<
      ({
        String sessionId,
        String answerSdp,
        int? offerAttempts,
        int? answerMs,
      })> sendOffer(String cameraUuid, String sdp) async {
    final id = 's${++_offers}';
    final hold = holdOffer;
    if (hold != null) await hold.future;
    final fail = failOfferWith;
    if (fail != null) {
      failOfferWith = null;
      throw fail;
    }
    if (unresponsive > 0) {
      unresponsive--;
      throw const CameraUnresponsiveException();
    }
    return (sessionId: id, answerSdp: 'answer', offerAttempts: 2, answerMs: 7800);
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
  Future<void> closeSession(String cameraUuid, String sessionId) async {
    closedSessions.add(sessionId);
    final hold = holdClose;
    if (hold != null) {
      holdClose = null; // 다음 close 한 번만 잡는다
      await hold.future;
    }
  }

  /// 다음 closeSession 응답을 테스트가 잡아 둔다(느린 서버 흉내).
  Completer<void>? holdClose;
}

TerraCamera _camera({required bool online}) => TerraCamera(
    id: _cam,
    cameraId: 'p4cam',
    name: 'cam',
    firmwareVer: '1.2.0',
    isOnline: online,
    createdAt: DateTime(2026, 9, 22));

class _Harness {
  final pcs = <_FakePc>[];
  final signaling = _FakeSignaling();
  final network = StreamController<String>();
  final cameras = StreamController<List<TerraCamera>>();
  final logs = <WebRtcConnectLog>[];
  final views = <LiveViewSummary>[];
  final diag = WebRtcDiagBuffer();
  late final ProviderContainer container;

  /// [start]가 false면 컨트롤러를 아직 만들지 않는다 — 테스트가 다른
  /// provider를 먼저 데운 뒤 [startController]로 시작한다.
  _Harness({bool start = true}) {
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
      webrtcConnectLogSinkProvider.overrideWithValue(logs.add),
      webrtcViewLogSinkProvider.overrideWithValue(views.add),
      webrtcDiagBufferProvider.overrideWithValue(diag),
    ]);
    if (start) startController();
    container.listen(camerasProvider, (_, __) {});
  }

  void startController() =>
      container.listen(webrtcLiveControllerProvider(_cam), (_, __) {});

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

/// 재생 중 통계 틱을 [n]번 흘린다.
Future<void> _ticks(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(kWebRtcStatsInterval);
    await tester.pump();
  }
}

/// 연결→첫 프레임까지 흘려 streaming 상태로 만든다.
Future<void> _stream(WidgetTester tester, _Harness h, {int frames = 5}) async {
  await _settleConnect(tester);
  h.pc.frames = frames;
  h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
  h.renderer.onFirstFrameRendered!();
  expect(h.state.phase, WebRtcLivePhase.streaming);
}

void main() {
  testWidgets('재연결 후 이전 세션의 ICE 후보가 새 피어에 섞이지 않는다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    expect(h.pcs, hasLength(1));
    expect(h.signaling.polls, ['s1']);
    final old = h.pc;

    old.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
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
    expect(h.state.phase, WebRtcLivePhase.recovering);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('재생 중 프레임이 5초 멈추면 stalled 안내, 15초면 다시 붙인다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    for (var i = 0; i < 4; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    expect(h.state.phase, WebRtcLivePhase.streaming);
    // 마지막 진행 뒤 5틱 무진행이면 stalled.
    await _ticks(tester, kWebRtcSoftStallTicks);
    expect(h.state.phase, WebRtcLivePhase.stalled);
    expect(h.state.renderer, isNotNull, reason: '마지막 장면을 지우지 않는다');
    await _ticks(tester, kWebRtcHardStallTicks - kWebRtcSoftStallTicks);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    expect(h.logs.last.outcome, 'stalled');
    expect(h.logs.last.failPhase, 'streaming');
    await h.dispose();
  });

  testWidgets('stalled 중 프레임이 다시 늘면 streaming으로 돌아온다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    await _ticks(tester, 1 + kWebRtcSoftStallTicks);
    expect(h.state.phase, WebRtcLivePhase.stalled);
    h.pc.frames += 1;
    await _ticks(tester, 1);
    expect(h.state.phase, WebRtcLivePhase.streaming);
    expect(h.pcs, hasLength(1));
    await h.dispose();
  });

  testWidgets('카운터가 줄어도(리셋) 정지로 보지 않고, 정적 피사체(프레임은 옴)는 멀쩡하다',
      (tester) async {
    final h = _Harness();
    await _stream(tester, h, frames: 900);
    await _ticks(tester, 1);
    h.pc.frames = 3; // SSRC 교체/카운터 리셋
    await _ticks(tester, 1);
    for (var i = 0; i < 20; i++) {
      h.pc.frames += 6; // 화면은 안 변해도 프레임은 온다
      await _ticks(tester, 1);
    }
    expect(h.state.phase, WebRtcLivePhase.streaming);
    await h.dispose();
  });

  testWidgets('통계를 10초 못 읽으면 statsUnknown만 켜고 연결은 유지한다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    h.pc.statsBroken = true;
    await _ticks(tester, kWebRtcStatsUnknownTicks);
    expect(h.state.phase, WebRtcLivePhase.streaming);
    expect(h.state.statsUnknown, isTrue);
    await _ticks(tester, 30);
    expect(h.pcs, hasLength(1), reason: '통계 부재만으로 끊지 않는다');
    h.pc.statsBroken = false;
    h.pc.frames += 6;
    await _ticks(tester, 1);
    expect(h.state.statsUnknown, isFalse);
    await h.dispose();
  });

  testWidgets('영상이 30초 안정되면 백오프가 초기화된다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    h.pc.frames = 5;
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.renderer.onFirstFrameRendered!();
    for (var i = 0; i < 31; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(3), reason: '초기화됐으면 6초가 아니라 3초 뒤에 붙는다');
    await h.dispose();
  });

  testWidgets('망 변경 뒤 프레임이 3틱 안에 안 늘면 그때 다시 붙는다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _stream(tester, h);
    await _ticks(tester, 1);
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    // 프레임이 계속 오면 유지.
    for (var i = 0; i < 5; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    expect(h.pcs, hasLength(1));
    // 다시 바뀌었는데 이번엔 프레임이 멈춤 → 3틱 뒤 재연결.
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _ticks(tester, kWebRtcNetworkFrameGraceTicks);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
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
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    expect(h.pcs.first.closed, isTrue);

    // 연결이 완전히 끊긴 순간(none)에는 헛시도하지 않는다.
    h.network.add('none');
    await tester.pump(kWebRtcNetworkDebounce);
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

  testWidgets('인증 실패(401)는 자동 재시도하지 않고 failed로 멈춘다', (tester) async {
    final h = _Harness();
    h.signaling.failOfferWith = const BackendException(401, 'expired');
    await _settleConnect(tester);
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_auth');
    await tester.pump(const Duration(minutes: 3));
    expect(h.pcs, hasLength(1), reason: '토큰이 죽었는데 offer를 반복하면 안 된다');
    await h.dispose();
  });

  testWidgets('ICE가 60초 안에 붙지도 실패하지도 않으면 시도 예산으로 끊고 다시 붙인다',
      (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    expect(h.state.phase, WebRtcLivePhase.connectingIce);
    final first = h.pc;
    await tester.pump(kWebRtcAttemptBudget);
    await tester.pump();
    expect(first.closed, isTrue);
    expect(h.logs.single.outcome, 'failed');
    expect(h.logs.single.failPhase, 'connectingIce');
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('1초 안에 wifi→mobile→wifi로 돌아오면 재연결하지 않는다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    h.network.add('mobile');
    await tester.pump(const Duration(milliseconds: 300));
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(1));
    expect(h.diag.events.where((e) => e.event == 'restart'), isEmpty);
    await h.dispose();
  });

  testWidgets('망이 없으면 재시도를 멈추고, 돌아오면 곧바로 붙는다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    h.network.add('none');
    await tester.pump(kWebRtcNetworkDebounce);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_no_network');
    await tester.pump(const Duration(minutes: 2));
    expect(h.pcs, hasLength(1), reason: '망 없이 offer를 반복하지 않는다');
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('정리 중 겹친 재시작 요청은 병합돼 offer가 하나만 나간다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    final n = h.container.read(webrtcLiveControllerProvider(_cam).notifier);
    unawaited(n.retry());
    unawaited(n.retry());
    unawaited(n.retry());
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    expect(
        h.diag.events.where((e) => e.event == 'restart-merged'), hasLength(2));
    await h.dispose();
  });

  testWidgets('연결 성공만으로는 백오프가 초기화되지 않는다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    // 1차 실패 → 3초, 2차 실패 → 6초.
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    // 영상 없이 곧 죽는 연결.
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2), reason: '3초 뒤가 아니라 6초 뒤에 붙어야 한다');
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(3));
    await h.dispose();
  });

  testWidgets('예산 안의 실패는 recovering(버튼 없음), 90초 넘기면 failed + 60초 간격',
      (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    expect(h.state.errorKey, isNull);
    // 90초를 흘린다. 그동안 재연결·60초 시도 예산 실패가 섞여 돌지만, 소진
    // 시점에 (a) 백오프 대기 중이면 즉시 failed, (b) 연결 시도 중이면 그 시도가
    // 실패할 때 failed — 둘 다 만들어 준다.
    await tester.pump(kWebRtcRecoveryBudget);
    await tester.pump();
    if (h.state.phase.isConnecting) {
      h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
      await tester.pump();
    }
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_failed');
    // 소진 뒤 재시도는 60초 간격 — 59초까지는 새 피어가 없고 61초에 하나.
    final before = h.pcs.length;
    await tester.pump(const Duration(seconds: 59));
    expect(h.pcs.length, before);
    await tester.pump(const Duration(seconds: 2));
    await _settleConnect(tester);
    expect(h.pcs.length, before + 1);
    await h.dispose();
  });

  testWidgets('안정 재생 뒤 끊기면 새 90초 창이 열린다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    for (var i = 0; i < 31; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    await tester.pump(const Duration(seconds: 80));
    expect(h.state.phase, isNot(WebRtcLivePhase.failed));
    await h.dispose();
  });

  testWidgets('수동 다시 연결은 예산 창을 새로 연다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(kWebRtcRecoveryBudget);
    await tester.pump();
    if (h.state.phase.isConnecting) {
      h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
      await tester.pump();
    }
    expect(h.state.phase, WebRtcLivePhase.failed);
    unawaited(h.container
        .read(webrtcLiveControllerProvider(_cam).notifier)
        .retry());
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    await h.dispose();
  });

  // ── 코드 리뷰 지적(2026-09-24) ───────────────────────────────────────

  testWidgets('망 신호가 이미 데워져 있어도 첫 전환에 다시 붙는다', (tester) async {
    final h = _Harness(start: false);
    // 홈 라이브가 먼저 떠서 망 신호 provider가 이미 값을 들고 있는 상황.
    h.container.listen(webrtcNetworkSignalProvider, (_, __) {});
    h.network.add('wifi');
    await tester.pump();
    h.startController();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    expect(h.pcs, hasLength(1));
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2), reason: '첫 전환을 기준선으로 삼켜서는 안 된다');
    await h.dispose();
  });

  testWidgets('빠른 복귀 뒤 늦게 끝난 이전 정리가 새 재생 상태를 덮지 않는다',
      (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    h.signaling.holdClose = Completer();
    final slowClose = h.signaling.holdClose!;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await _stream(tester, h);
    expect(h.pcs, hasLength(2));
    slowClose.complete(); // 이전 세션 close가 이제야 끝난다
    await tester.pump();
    await tester.pump();
    expect(h.state.phase, WebRtcLivePhase.streaming);
    expect(h.state.renderer, isNotNull);
    await h.dispose();
  });

  testWidgets('백그라운드 중 망이 바뀌어도 복귀 뒤 같은 신호로 다시 붙지 않는다',
      (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _stream(tester, h);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    // 복귀 직후 connectivity가 같은 값을 다시 알린다.
    h.network.add('wifi,mobile');
    await tester.pump();
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2), reason: '이미 LTE로 붙은 연결을 다시 취소하면 안 된다');
    await h.dispose();
  });

  testWidgets('망 변경 뒤 무진행 재연결은 stalled로 기록한다(closed 아님)', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _stream(tester, h);
    await _ticks(tester, 1);
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    await _ticks(tester, kWebRtcNetworkFrameGraceTicks);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    expect(h.logs.map((l) => l.outcome), ['streaming', 'stalled']);
    expect(h.logs.last.failPhase, 'streaming');
    await h.dispose();
  });

  // ── S21+ 실기기 망 끊김 시험(2026-09-24) ─────────────────────────────

  testWidgets('휴대폰 망이 없으면 카메라 목록이 오프라인이어도 "인터넷 없음"으로 안내한다',
      (tester) async {
    final h = _Harness();
    h.cameras.add([_camera(online: false)]); // 망 끊긴 사이 낡은 목록
    h.network.add('wifi');
    await _stream(tester, h);
    h.network.add('none');
    await tester.pump(kWebRtcNetworkDebounce);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_no_network',
        reason: '폰 문제를 카메라 탓으로 안내하면 안 된다');
    // 같은 Wi-Fi로 돌아오면 버튼 없이 곧바로 다시 붙는다.
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('카메라 오프라인 대기 중에도 폰 망이 끊겼다 돌아오면 한 번 다시 붙는다',
      (tester) async {
    final h = _Harness();
    h.cameras.add([_camera(online: false)]);
    h.network.add('wifi');
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.errorKey, 'crecam_live_error_camera_offline');
    // 폰이 잠깐 오프라인 — 그동안 카메라 온라인 알림(Realtime)을 놓칠 수 있다.
    h.network.add('none');
    await tester.pump(kWebRtcNetworkDebounce);
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2), reason: '같은 Wi-Fi로 돌아와도 갇히면 안 된다');
    await h.dispose();
  });

  // ── 정지 원인 진단: 수신 멈춤 vs 디코딩 멈춤(2026-09-24) ─────────────

  Map<String, Object?> stallData(_Harness h, String event) =>
      h.diag.events.lastWhere((e) => e.event == event).data;

  testWidgets('정지 중 데이터도 안 오면 no-data로 기록한다(카메라·망 쪽)', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    h.pc
      ..bytes = 1000
      ..lost = 0;
    await _ticks(tester, 1);
    await _ticks(tester, kWebRtcSoftStallTicks);
    final d = stallData(h, 'stall-soft');
    expect(d['cause'], 'no-data');
    expect(d['bytes_delta'], 0);
    await h.dispose();
  });

  testWidgets('데이터는 오는데 프레임이 멈추면 data-no-decode(앱·디코더·키프레임 쪽)',
      (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    h.pc
      ..bytes = 1000
      ..lost = 0;
    await _ticks(tester, 1);
    for (var i = 0; i < kWebRtcSoftStallTicks; i++) {
      h.pc
        ..bytes = h.pc.bytes! + 5000
        ..lost = h.pc.lost! + 2;
      await _ticks(tester, 1);
    }
    final d = stallData(h, 'stall-soft');
    expect(d['cause'], 'data-no-decode');
    expect(d['bytes_delta'], 25000);
    expect(d['lost_delta'], 10);
    // 회복 행에는 정지 동안의 누계와 길이가 남는다.
    h.pc.frames += 6;
    await _ticks(tester, 1);
    final r = stallData(h, 'stall-recovered');
    expect(r['stalled_ticks'], kWebRtcSoftStallTicks);
    expect(r['bytes_delta'], 25000);
    await h.dispose();
  });

  testWidgets('멈추기 직전에만 조금 오고 그 뒤 끊기면 no-data(최근 수신 기준)',
      (tester) async {
    // S21+ 실측(03:14): 5초·15초 시점 누계가 똑같이 20,608B — 손상된 꼬리만
    // 오고 수신이 끊겼는데 누계 기준이라 data-no-decode로 찍혔다.
    final h = _Harness();
    await _stream(tester, h);
    h.pc
      ..bytes = 1000
      ..lost = 0;
    await _ticks(tester, 1);
    h.pc
      ..bytes = 21608
      ..lost = 16;
    await _ticks(tester, 2); // 정지 초반에만 조금 들어온다
    await _ticks(tester, kWebRtcSoftStallTicks - 2);
    final d = stallData(h, 'stall-soft');
    expect(d['cause'], 'no-data');
    expect(d['recent_bytes'], 0);
    expect(d['bytes_delta'], 20608, reason: '정지 구간 누계는 참고로 남긴다');
    await h.dispose();
  });

  testWidgets('수신 바이트 통계가 없으면 unknown — 추측하지 않는다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    await _ticks(tester, 1 + kWebRtcSoftStallTicks);
    expect(stallData(h, 'stall-soft')['cause'], 'unknown');
    await h.dispose();
  });

  // ── 연결 결과 기록(webrtc_connect_logs, 2026-09-23) ─────────────────────

  testWidgets('기록 — 첫 프레임에 streaming 행, 화면을 떠나면 closed 행', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.renderer.onFirstFrameRendered!();
    await tester.pump();
    expect(h.logs, hasLength(1));
    final ok = h.logs.single;
    expect(ok.outcome, 'streaming');
    expect(ok.failPhase, isNull);
    expect(ok.network, 'wifi');
    expect(ok.offerAttempts, 2);
    expect(ok.answerMs, 7800);
    expect((ok.localCand, ok.remoteCand), ('srflx', 'host'));
    expect(ok.msConnected, isNotNull);
    expect(ok.msFirstFrame, isNotNull);
    expect(ok.reconnectAttempt, 0);

    await h.dispose();
    await tester.pump();
    expect(h.logs, hasLength(2));
    expect(h.logs.last.outcome, 'closed');
    expect(h.logs.last.failPhase, isNull);
    expect(h.logs.last.streamedSec, isNotNull);
  });

  testWidgets('시청 세션 — 화면을 떠나면 요약 1행, 연결 행과 view_id·펌웨어로 묶인다',
      (tester) async {
    // 실제 앱처럼 카메라 목록이 로드된 뒤 라이브를 시작한다.
    final h = _Harness(start: false);
    h.cameras.add([_camera(online: true)]);
    h.network.add('wifi');
    h.container.listen(webrtcNetworkSignalProvider, (_, __) {});
    await tester.pump();
    h.startController();
    await _stream(tester, h);
    await tester.pump(const Duration(seconds: 4));
    expect(h.views, isEmpty); // 끝나기 전엔 쓰지 않는다

    await h.dispose();
    await tester.pump();
    final v = h.views.single;
    expect(v.endReason, LiveViewEnd.closed);
    expect(v.firstVideoMs, isNotNull);
    expect(v.attempts, 1);
    expect(v.msVideo, greaterThanOrEqualTo(4000));
    expect(v.firmwareVer, '1.2.0');
    expect(v.cameraOnline, isTrue);
    expect(v.network, 'wifi');
    expect(h.logs, isNotEmpty);
    for (final l in h.logs) {
      expect(l.viewId, v.viewId);
      expect(l.firmwareVer, '1.2.0');
    }
  });

  testWidgets('시청 세션 — 백그라운드에서 닫히고, 복귀하면 새 세션이 열린다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    expect(h.views, hasLength(1));
    expect(h.views.first.endReason, LiveViewEnd.background);

    await tester.pump(const Duration(minutes: 2)); // 백그라운드 시간은 안 센다
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await _settleConnect(tester);
    await h.dispose();
    await tester.pump();

    expect(h.views, hasLength(2));
    final second = h.views.last;
    expect(second.viewId, isNot(h.views.first.viewId));
    expect(second.endReason, LiveViewEnd.closed);
    expect(second.restarts, {'resume': 1});
    expect(second.firstVideoMs, isNull); // 복귀 뒤엔 영상 전에 떠났다
    expect(second.durationMs, lessThan(60000));
    expect(h.logs.last.viewId, second.viewId);
  });

  testWidgets('시청 세션 — 이전 정리가 안 끝난 빠른 복귀는 옛 재생 상태를 새 세션에 넘기지 않는다',
      (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    h.signaling.holdClose = Completer();
    final slowClose = h.signaling.holdClose!;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    expect(h.state.phase, WebRtcLivePhase.streaming); // 정리 대기 중 — 옛 상태
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await _settleConnect(tester); // 새 연결은 영상 없이 끝난다
    slowClose.complete();
    await tester.pump();
    await h.dispose();
    await tester.pump();

    expect(h.views, hasLength(2));
    final second = h.views.last;
    expect(second.firstVideoMs, isNull);
    expect(second.msVideo, 0);
  });

  testWidgets('시청 세션 — 실패 화면 시간·수동 재시도·재연결 사유를 남긴다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    await tester.pump(const Duration(seconds: 3)); // 백오프 → timer 재연결
    await _settleConnect(tester);
    unawaited(h.container
        .read(webrtcLiveControllerProvider(_cam).notifier)
        .retry());
    await _settleConnect(tester);
    await h.dispose();
    await tester.pump();

    final v = h.views.single;
    expect(v.manualRetries, 1);
    expect(v.restarts, {'timer': 1, 'manual': 1});
    expect(v.attempts, 3);
    expect(v.msRecovering, greaterThanOrEqualTo(3000));
    expect(v.firstVideoMs, isNull);
  });

  testWidgets('기록 — 504 두 번이면 unresponsive 행 둘(offer_attempts=3)',
      (tester) async {
    final h = _Harness();
    h.signaling.unresponsive = 2;
    // 가짜 피어는 ICE 수집이 즉시 끝나 1차 504 → 2초 뒤 2차 504가 이 안에 끝난다.
    await _settleConnect(tester);
    await tester.pump();
    expect(h.state.phase, WebRtcLivePhase.recovering);
    expect(h.logs.map((l) => l.outcome), ['unresponsive', 'unresponsive']);
    expect(h.logs.every((l) => l.offerAttempts == 3), isTrue);
    expect(h.logs.every((l) => l.failPhase == 'offering'), isTrue);
    await h.dispose();
    await tester.pump();
    expect(h.logs, hasLength(2), reason: '이미 끝난 세대는 다시 쓰지 않는다');
  });

  testWidgets('기록 — 연결 후 무영상은 no_video, 재생 중 정지는 stalled', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    await tester.pump(kWebRtcFirstFrameTimeout);
    await tester.pump();
    expect(h.logs.single.outcome, 'no_video');
    expect(h.logs.single.failPhase, 'waitingVideo');
    expect(h.logs.single.localCand, 'srflx');

    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    h.pc.frames = 5;
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.renderer.onFirstFrameRendered!();
    await _ticks(tester, 1 + kWebRtcHardStallTicks);
    expect(h.logs.map((l) => l.outcome), ['no_video', 'streaming', 'stalled']);
    expect(h.logs[1].reconnectAttempt, 1);
    expect(h.logs.last.failPhase, 'streaming');
    expect(h.logs.last.streamedSec, isNotNull);
    await h.dispose();
  });

  testWidgets('기록 — 결과 전에 네트워크가 바뀌면 cancelled', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    expect(h.state.phase, WebRtcLivePhase.connectingIce);
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.logs.first.outcome, 'cancelled');
    expect(h.logs.first.failPhase, 'connectingIce');
    expect(h.logs.first.network, 'wifi');
    await h.dispose();
  });

  test('selectedCandidateTypes — transport 없으면 nominated 쌍, 모르는 타입은 null',
      () {
    final reports = [
      StatsReport('p1', 'candidate-pair', 0, {
        'nominated': 'true',
        'state': 'succeeded',
        'localCandidateId': 'l',
        'remoteCandidateId': 'r',
      }),
      StatsReport('l', 'local-candidate', 0, {'candidateType': 'relay'}),
      StatsReport('r', 'remote-candidate', 0, {'candidateType': 'weird'}),
    ];
    expect(selectedCandidateTypes(reports), ('relay', null));
    expect(selectedCandidateTypes([]), (null, null));
  });

  test('toRow — null 필드는 빼고 보낸다(DB 기본값·CHECK 보호)', () {
    final row = const WebRtcConnectLog(cameraId: 'c', outcome: 'failed')
        .toRow(appVersion: '1.0.0+1');
    expect(row, {'camera_id': 'c', 'outcome': 'failed', 'app_version': '1.0.0+1'});
  });
}
