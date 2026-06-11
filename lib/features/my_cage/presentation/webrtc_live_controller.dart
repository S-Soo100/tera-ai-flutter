import 'dart:async';

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

  // ── 공개 API ────────────────────────────────────────────────────────────────

  /// 현재 세션 정리 후 처음부터 재시작
  Future<void> retry() async {
    await _cleanup(closeRemote: true);
    _active = true;
    _pendingCandidates.clear();
    state = const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig);
    _start();
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
      state = WebRtcLiveState(
        phase: WebRtcLivePhase.failed,
        errorKey: 'crecam_live_error_unresponsive',
      );
    } catch (_) {
      if (!_active) return;
      state = WebRtcLiveState(
        phase: WebRtcLivePhase.failed,
        errorKey: 'crecam_live_error_failed',
      );
    }
  }

  Future<void> _doConnect() async {
    final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);

    // 1. fetchConfig
    final cfg = await signalingRepo.fetchConfig();
    if (!_active) return;

    // 2. renderer 초기화
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _renderer = renderer;

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

    // 9. ICE gathering complete 대기 (최대 2초) — trickle 불안정 회피
    await _waitForIceGathering(pc, maxWaitMs: 2000);
    if (!_active) return;

    // 10. gathered SDP로 offer 전송
    final localDesc = await pc.getLocalDescription();
    final offerResult = await signalingRepo.sendOffer(
      cameraUuid,
      localDesc!.sdp!,
    );
    if (!_active) return;

    _sessionId = offerResult.sessionId;

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
    final timer = Timer(Duration(milliseconds: maxWaitMs), () {
      if (!completer.isCompleted) completer.complete();
    });
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) completer.complete();
      }
    };
    await completer.future;
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
