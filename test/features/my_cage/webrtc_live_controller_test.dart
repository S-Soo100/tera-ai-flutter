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
        StatsReport('in', 'inbound-rtp', 0,
            {'kind': 'video', 'framesDecoded': frames}),
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
  final logs = <WebRtcConnectLog>[];
  final diag = WebRtcDiagBuffer();
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
      webrtcConnectLogSinkProvider.overrideWithValue(logs.add),
      webrtcDiagBufferProvider.overrideWithValue(diag),
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
    expect(h.state.phase, WebRtcLivePhase.failed);
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

  testWidgets('기록 — 504 두 번이면 unresponsive 행 둘(offer_attempts=3)',
      (tester) async {
    final h = _Harness();
    h.signaling.unresponsive = 2;
    // 가짜 피어는 ICE 수집이 즉시 끝나 1차 504 → 2초 뒤 2차 504가 이 안에 끝난다.
    await _settleConnect(tester);
    await tester.pump();
    expect(h.state.phase, WebRtcLivePhase.failed);
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
