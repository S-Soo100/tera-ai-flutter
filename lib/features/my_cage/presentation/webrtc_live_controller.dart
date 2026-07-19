import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/camera_exceptions.dart';
import 'my_cage_providers.dart';

// ── 상태 정의 ─────────────────────────────────────────────────────────────────

enum WebRtcLivePhase {
  connectingConfig,
  offering,
  connectingIce,
  streaming,
  failed,
}

class WebRtcLiveState {
  final WebRtcLivePhase phase;
  final String? errorKey; // ko.json 키
  final RTCVideoRenderer? renderer;

  const WebRtcLiveState({
    required this.phase,
    this.errorKey,
    this.renderer,
  });

  WebRtcLiveState copyWith({
    WebRtcLivePhase? phase,
    String? errorKey,
    bool clearError = false,
    RTCVideoRenderer? renderer,
  }) {
    return WebRtcLiveState(
      phase: phase ?? this.phase,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      renderer: renderer ?? this.renderer,
    );
  }
}

// ── 컨트롤러 ─────────────────────────────────────────────────────────────────

class WebRtcLiveController
    extends StateNotifier<WebRtcLiveState> {
  WebRtcLiveController(this.ref, this.cameraUuid)
      : super(const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig)) {
    _start();
  }

  final Ref ref;
  final String cameraUuid;

  RTCPeerConnection? _pc;
  RTCVideoRenderer? _renderer;
  String? _sessionId;
  bool _active = true;

  // ICE 후보: sessionId 확보 전 로컬 큐
  final List<RTCIceCandidate> _pendingCandidates = [];

  // 504(카메라 무응답) 자동 재시도 1회 가드. 수동 retry()가 리셋한다.
  bool _autoRetried = false;

  // ICE gathering 대기 중 srflx 후보 감지용 probe (조기 진행).
  void Function(String raw)? _iceWaitProbe;

  // 연결 단계 계측 (ms 누적): 느린 구간이 앱/펌웨어/NAT 중 어디인지 판별용.
  final Stopwatch _timing = Stopwatch();
  int? _msConfig; // config+renderer 준비 완료
  int? _msAnswer; // offer 전송 → answer 수신 (≒ 펌웨어 응답 시간 포함)

  // ── 공개 API ────────────────────────────────────────────────────────────────

  /// 수동 재시도 (실패 화면 버튼). 자동 재시도 가드와 config 캐시를 리셋한다.
  Future<void> retry() async {
    _autoRetried = false;
    ref.invalidate(webrtcConfigProvider);
    await _restart();
  }

  Future<void> _restart() async {
    await _cleanup(closeRemote: true);
    _active = true;
    _pendingCandidates.clear();
    state = const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig);
    await _start();
  }

  @override
  void dispose() {
    _active = false;
    _cleanup(closeRemote: true);
    super.dispose();
  }

  // ── 연결 시퀀스 ────────────────────────────────────────────────────────────

  Future<void> _start() async {
    try {
      await _doConnect();
    } on CameraUnresponsiveException {
      if (!_active) return;
      if (!_autoRetried) {
        // 펌웨어가 offer를 놓친 일시 무응답일 수 있어 1회만 자동 재시도.
        _autoRetried = true;
        await _restart();
        return;
      }
      debugPrint(
        '[webrtc-timing] cam=$cameraUuid FAILED(unresponsive) '
        'config=${_msConfig}ms at=${_timing.elapsedMilliseconds}ms',
      );
      state = const WebRtcLiveState(
        phase: WebRtcLivePhase.failed,
        errorKey: 'crecam_live_error_unresponsive',
      );
    } catch (_) {
      if (!_active) return;
      debugPrint(
        '[webrtc-timing] cam=$cameraUuid FAILED phase=${state.phase} '
        'config=${_msConfig}ms answer=${_msAnswer}ms '
        'at=${_timing.elapsedMilliseconds}ms',
      );
      state = const WebRtcLiveState(
        phase: WebRtcLivePhase.failed,
        errorKey: 'crecam_live_error_failed',
      );
    }
  }

  Future<void> _doConnect() async {
    _timing
      ..reset()
      ..start();
    final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);

    // 1+2. config(세션 캐시)와 renderer init을 병렬로
    final rendererFut = () async {
      final r = RTCVideoRenderer();
      await r.initialize();
      return r;
    }();
    Map<String, dynamic> cfg;
    try {
      cfg = await ref.read(webrtcConfigProvider.future);
    } catch (_) {
      await (await rendererFut).dispose(); // 실패 경로 native 누수 방지
      rethrow;
    }
    final renderer = await rendererFut;
    if (!_active) {
      await renderer.dispose();
      return;
    }
    _renderer = renderer;
    _msConfig = _timing.elapsedMilliseconds;

    // 첫 프레임 도착 계측: connected 이후 화면이 실제로 뜨기까지의 간극
    // (펌웨어 첫 키프레임 대기 여부 판별). RTCVideoView는 connected 시점에
    // 이미 마운트돼 텍스처가 렌더되므로 콜백이 정상 발화한다.
    renderer.onFirstFrameRendered = () {
      if (!_active) return;
      debugPrint(
        '[webrtc-timing] cam=$cameraUuid firstFrame='
        '${_timing.elapsedMilliseconds}ms',
      );
    };

    // 3. PeerConnection 생성
    final pc = await createPeerConnection({
      'iceServers': cfg['iceServers'] ?? [],
      'sdpSemantics': cfg['sdpSemantics'] ?? 'unified-plan',
    });
    _pc = pc;

    // 4. addTransceiver: 수신 전용 (마이크/카메라 권한 요청 없음)
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    // 5. 원격 트랙 → renderer.srcObject
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
      }
    };

    // 6. ICE 후보 수집 핸들러
    pc.onIceCandidate = (candidate) {
      if (!_active) return;
      // gathering 완료 신호(candidate null/빈 값)는 서버로 보내지 않음 (계약 §4.3)
      final raw = candidate.candidate;
      if (raw == null || raw.isEmpty) return;
      _iceWaitProbe?.call(raw);
      final sessionId = _sessionId;
      if (sessionId == null) {
        // sessionId 확보 전: 로컬 큐에 적재
        _pendingCandidates.add(candidate);
      } else {
        // 즉시 전송
        _sendCandidateAsync(sessionId, candidate);
      }
    };

    // 7. 연결 상태 모니터링
    pc.onConnectionState = (state) {
      if (!_active) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint(
          '[webrtc-timing] cam=$cameraUuid config=${_msConfig}ms '
          'answer=${_msAnswer}ms connected=${_timing.elapsedMilliseconds}ms',
        );
        this.state = this.state.copyWith(
              phase: WebRtcLivePhase.streaming,
              clearError: true,
              renderer: renderer,
            );
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        this.state = WebRtcLiveState(
          phase: WebRtcLivePhase.failed,
          errorKey: 'crecam_live_error_failed',
          renderer: renderer,
        );
      }
    };

    // phase: offering — renderer 포함해서 전달
    if (!_active) return;
    state = WebRtcLiveState(
      phase: WebRtcLivePhase.offering,
      renderer: renderer,
    );

    // 8. createOffer → setLocalDescription
    final offerSdp = await pc.createOffer({'offerToReceiveVideo': true});
    await pc.setLocalDescription(offerSdp);

    // 9. ICE gathering 대기 (최대 1초) — srflx 확보 시 조기 진행.
    //    나머지 후보는 answer 후 trickle(큐 flush + POST /ice)로 전송된다.
    await _waitForIceGathering(pc, maxWaitMs: 1000);
    if (!_active) return;

    // 10. gathered SDP로 offer 전송
    final localDesc = await pc.getLocalDescription();
    final offerResult = await signalingRepo.sendOffer(
      cameraUuid,
      localDesc!.sdp!,
    );
    if (!_active) return;

    _sessionId = offerResult.sessionId;
    _msAnswer = _timing.elapsedMilliseconds;

    // 11. setRemoteDescription
    await pc.setRemoteDescription(
      RTCSessionDescription(offerResult.answerSdp, 'answer'),
    );

    // 12. 큐에 쌓인 로컬 ICE 후보 flush
    for (final c in _pendingCandidates) {
      _sendCandidateAsync(offerResult.sessionId, c);
    }
    _pendingCandidates.clear();

    // 13. ICE 폴링 루프 시작 (백그라운드)
    if (!_active) return;
    state = state.copyWith(phase: WebRtcLivePhase.connectingIce);
    unawaited(_pollIceCandidates(offerResult.sessionId));
  }

  // ── ICE gathering 대기 ────────────────────────────────────────────────────

  Future<void> _waitForIceGathering(
    RTCPeerConnection pc, {
    required int maxWaitMs,
  }) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    final timer = Timer(Duration(milliseconds: maxWaitMs), finish);
    // srflx(STUN 반사 주소)가 잡히면 공인망 후보 확보 완료 — TURN 미배포라
    // relay 후보는 없으므로 더 기다릴 이유가 없다.
    _iceWaitProbe = (raw) {
      if (raw.contains(' typ srflx')) finish();
    };
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) finish();
    };
    await completer.future;
    _iceWaitProbe = null;
    timer.cancel();
  }

  // ── ICE 폴링 루프 ─────────────────────────────────────────────────────────

  Future<void> _pollIceCandidates(String sessionId) async {
    final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);
    int sinceIndex = 0;

    while (_active) {
      // 계약 §4.3: connected / failed / closed 면 폴링 중단
      final pcState = _pc?.connectionState;
      if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          pcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          pcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        break;
      }

      try {
        final result = await signalingRepo.pollCandidates(
          cameraUuid,
          sessionId,
          sinceIndex,
        );
        if (!_active) break;

        for (final cJson in result.candidates) {
          try {
            await _pc?.addCandidate(
              RTCIceCandidate(
                cJson['candidate'] as String?,
                cJson['sdpMid'] as String?,
                cJson['sdpMLineIndex'] as int?,
              ),
            );
          } catch (_) {
            // 개별 실패 무시, 계속
          }
        }
        sinceIndex = result.nextIndex;
      } catch (_) {
        if (!_active) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────

  void _sendCandidateAsync(String sessionId, RTCIceCandidate candidate) {
    final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);
    unawaited(signalingRepo.sendIceCandidate(
      cameraUuid,
      sessionId,
      {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    ));
  }

  /// dispose 시 세션 정리.
  /// [closeRemote]: true면 terra-server에 closeSession 요청
  Future<void> _cleanup({required bool closeRemote}) async {
    _active = false;
    final sessionId = _sessionId;
    _sessionId = null;

    await _pc?.close();
    _pc = null;

    if (closeRemote && sessionId != null) {
      final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);
      await signalingRepo.closeSession(cameraUuid, sessionId);
    }

    await _renderer?.dispose();
    _renderer = null;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final webrtcLiveControllerProvider = StateNotifierProvider.autoDispose
    .family<WebRtcLiveController, WebRtcLiveState, String>(
  (ref, cameraUuid) => WebRtcLiveController(ref, cameraUuid),
);
