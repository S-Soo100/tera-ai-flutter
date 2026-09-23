import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/camera_exceptions.dart';
import '../data/webrtc_connect_log_repository.dart';
import '../data/webrtc_signaling_repository.dart';
import '../domain/terra_camera.dart';
import '../domain/webrtc_connect_log.dart';
import '../domain/webrtc_diag.dart';
import 'my_cage_providers.dart';
import 'webrtc_diag_providers.dart';

// ── 상태 정의 ─────────────────────────────────────────────────────────────────

enum WebRtcLivePhase {
  connectingConfig,
  offering,
  connectingIce,

  /// ICE는 붙었고 첫 영상 프레임을 기다리는 중(키프레임 대기).
  waitingVideo,
  streaming,

  /// 재생 중 디코딩이 [kWebRtcSoftStallTicks]초 멈춤 — renderer는 살아 있어
  /// 마지막 장면이 남고, 위에 "잠시 멈췄어요" 안내를 얹는다.
  stalled,

  /// 실패 뒤 집중 복구 예산([kWebRtcRecoveryBudget]) 안의 자동 재시도 대기.
  /// 사용자에게 버튼을 요구하지 않는다.
  recovering,

  /// 집중 복구 예산 소진·카메라 오프라인·망 없음·인증 실패. "다시 연결" 버튼이
  /// 있고 저빈도([kWebRtcLowRetryInterval]) 자동 재시도만 돈다.
  failed,
}

extension WebRtcLivePhaseX on WebRtcLivePhase {
  /// 영상 면을 그릴 renderer가 있는 단계.
  bool get hasVideo =>
      this == WebRtcLivePhase.streaming || this == WebRtcLivePhase.stalled;

  /// 연결 시퀀스 진행 중(config~첫 프레임 대기).
  bool get isConnecting => index <= WebRtcLivePhase.waitingVideo.index;
}

class WebRtcLiveState {
  final WebRtcLivePhase phase;
  final String? errorKey; // ko.json 키
  final RTCVideoRenderer? renderer;

  /// 재생 중 통계를 [kWebRtcStatsUnknownTicks]초 연속 못 읽음 — 영상은 나올 수
  /// 있으니 가리지 않고, "영상 상태 확인 중"만 얹는다.
  final bool statsUnknown;

  const WebRtcLiveState({
    required this.phase,
    this.errorKey,
    this.renderer,
    this.statsUnknown = false,
  });

  WebRtcLiveState copyWith({
    WebRtcLivePhase? phase,
    String? errorKey,
    bool clearError = false,
    RTCVideoRenderer? renderer,
    bool? statsUnknown,
  }) {
    return WebRtcLiveState(
      phase: phase ?? this.phase,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      renderer: renderer ?? this.renderer,
      statsUnknown: statsUnknown ?? this.statsUnknown,
    );
  }
}

// ── 교체 가능한 의존성 (테스트 심) ────────────────────────────────────────────

typedef PeerConnectionFactory = Future<RTCPeerConnection> Function(
    Map<String, dynamic> configuration);
typedef VideoRendererFactory = Future<RTCVideoRenderer> Function();

/// 피어 연결 생성. 테스트가 가짜 피어로 바꿔 끼운다.
final webrtcPeerConnectionFactoryProvider =
    Provider<PeerConnectionFactory>((_) => (c) => createPeerConnection(c));

/// 렌더러 생성(+native initialize). 테스트가 가짜 렌더러로 바꿔 끼운다.
final webrtcRendererFactoryProvider =
    Provider<VideoRendererFactory>((_) => () async {
          final r = RTCVideoRenderer();
          await r.initialize();
          return r;
        });

/// 네트워크 종류 신호("wifi,mobile" 등). 바뀌면 라이브를 즉시 다시 붙인다 —
/// Wi-Fi↔LTE 전환은 기존 ICE 경로를 죽이는데, WebRTC가 failed를 선언하고
/// 백오프가 도는 동안(최대 60초+) 화면이 멈춰 있었다(2026-09-22).
final webrtcNetworkSignalProvider = StreamProvider<String>((ref) async* {
  final connectivity = Connectivity();
  String sig(List<ConnectivityResult> r) =>
      (r.map((e) => e.name).toList()..sort()).join(',');
  yield sig(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(sig);
});

/// 연결 결과 기록(`webrtc_connect_logs`, 2026-09-23). 테스트가 목록으로 받는다.
/// 기록은 fire-and-forget — 실패해도 라이브 흐름에 영향이 없다.
typedef WebRtcConnectLogSink = void Function(WebRtcConnectLog log);

final webrtcConnectLogSinkProvider = Provider<WebRtcConnectLogSink>((ref) {
  final repo = WebRtcConnectLogRepository(ref.watch(supabaseClientProvider));
  return (log) => unawaited(repo.insert(log));
});

/// 연결 한 번(세대)의 계측값. 결과 행과 재생 종료 행이 같은 값을 공유한다.
class _Attempt {
  _Attempt(this.gen, this.reconnectAttempt, this.network);

  final int gen;
  final int reconnectAttempt;

  /// 시도 시작 때의 네트워크 종류. 첫 시도는 신호가 아직 안 와 있을 수 있어
  /// config 단계에서 한 번 더 채운다.
  String? network;
  int? msConfig;
  int? msAnswer;
  int? msConnected;
  int? msFirstFrame;
  int? offerAttempts;
  int? answerMs;

  /// ICE connected 때 조회한 선택 후보 쌍 타입(로컬, 원격).
  Future<(String?, String?)>? candidates;

  /// 첫 프레임 이후 재생 시간.
  Stopwatch? playing;

  /// 결과 행(`streaming` 제외)을 이미 썼다 — 한 세대에 종료 행은 하나.
  bool ended = false;
}

const _kFailPhase = {
  WebRtcLivePhase.connectingConfig: 'config',
  WebRtcLivePhase.offering: 'offering',
  WebRtcLivePhase.connectingIce: 'connectingIce',
  WebRtcLivePhase.waitingVideo: 'waitingVideo',
  WebRtcLivePhase.streaming: 'streaming',
  WebRtcLivePhase.stalled: 'streaming',
};

// ── 타이밍 상수 ──────────────────────────────────────────────────────────────

/// ICE 후보 수집 대기 — 계약 권장 2초(APP_WEBRTC.md). 1초면 느린 망에서 공인
/// 주소(srflx) 없이 offer가 나가고, 뒤늦은 후보는 펌웨어 trickle에 기대야 한다.
const kWebRtcIceGatherWait = Duration(seconds: 2);

/// 504(카메라 무응답) 자동 재시도 전 대기 — 방금 못 받은 카메라에 즉시 다시
/// 보내면 같은 이유로 또 놓친다.
const kWebRtcUnresponsiveRetryDelay = Duration(seconds: 2);

/// ICE 연결 후 첫 영상 프레임을 기다리는 한도. 펌웨어 키프레임 간격 때문에
/// 첫 화면까지 ~18초가 실측됐다(메모리 webrtc_first_frame_keyframe_gap) — 그보다
/// 넉넉히 둔다. 넘기면 영상 없는 연결로 보고 다시 붙인다.
const kWebRtcFirstFrameTimeout = Duration(seconds: 30);

/// 재생 중 통계 샘플 주기. getStats는 겹치지 않게 호출한다(busy 가드).
const kWebRtcStatsInterval = Duration(seconds: 1);

/// 디코딩 프레임이 이 틱만큼 연속 그대로면 `stalled`(안내만, 연결 유지).
/// GOP 15/6fps = 키프레임 2.5초라 3초면 정상 손실에도 깜빡인다(기획 §11.3).
const kWebRtcSoftStallTicks = 5;

/// 이 틱만큼 연속 그대로면 재연결. 시각이 아니라 틱으로 세는 이유: 테스트의
/// 가짜 시계는 Timer만 흘린다(기획 §11.3).
const kWebRtcHardStallTicks = 15;

/// 통계를 이 틱만큼 연속 못 읽으면 `statsUnknown`(연결은 끊지 않는다).
const kWebRtcStatsUnknownTicks = 10;

/// 첫 프레임 뒤 이 시간 동안 `streaming`이 유지돼야 백오프·복구 예산을 초기화.
const kWebRtcStableAfter = Duration(seconds: 30);

/// 개별 연결 시도(config 수신~첫 프레임) 전체 예산. ICE 연결 단계엔 다른
/// 한도가 없어 이것이 유일한 상한이다(기획 §11.2).
const kWebRtcAttemptBudget = Duration(seconds: 60);

/// 시청 진입·끊김 뒤 자동 복구를 `recovering`으로 조용히 반복하는 예산.
/// 넘기면 `failed`(버튼) + 저빈도 재시도.
const kWebRtcRecoveryBudget = Duration(seconds: 90);
const kWebRtcLowRetryInterval = Duration(seconds: 60);

/// connectivity_plus 신호 합치기 창.
const kWebRtcNetworkDebounce = Duration(seconds: 1);

/// 망 신호가 바뀌어도 프레임이 이 틱 안에 진행하면 연결을 유지한다.
const kWebRtcNetworkFrameGraceTicks = 3;

// ── 컨트롤러 ─────────────────────────────────────────────────────────────────

/// 연결 한 번(= 세대). 재연결·일시정지마다 세대를 올리고, 이전 세대의 비동기
/// 잔여 작업(offer 응답·ICE 폴링·상태 콜백·타이머)은 세대가 다르면 아무것도
/// 하지 않는다.
///
/// 2026-09-22 이전엔 공유 `_active` 플래그 하나로 막았는데, 재시작이
/// `_active`를 곧바로 true로 되돌려 **이전 세션의 ICE 폴링이 살아남아 새
/// 피어에 이전 세션 후보를 넣었다** — 연결 실패 → 재연결 → 또 섞임의 반복.
class WebRtcLiveController extends StateNotifier<WebRtcLiveState> {
  /// **생성자는 아무것도 시작하지 않는다**(2026-09-07, 리뷰 잔여 A2).
  /// 실피어 연결은 provider가 [startConnection]으로 켠다 — 예전엔 생성자가
  /// 곧장 시그널링을 시작해, 위젯 테스트마다 우회(빌더 심·'마지막 페이지'
  /// 관례)가 필요했다. 테스트는 provider를 **시작하지 않은 컨트롤러**로
  /// 오버라이드하면 된다(connectingConfig 스켈레톤으로 멈춘다).
  WebRtcLiveController(this.ref, this.cameraUuid)
      : super(const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig));

  final Ref ref;
  final String cameraUuid;

  bool _started = false;

  /// 연결 시퀀스 시작. 멱등 — provider가 생성 직후 1회 부른다.
  /// 앱 수명주기·네트워크·카메라 온라인 감시도 여기서 켠다.
  void startConnection() {
    if (_started) return;
    _started = true;
    _logSink = ref.read(webrtcConnectLogSinkProvider);
    _diagBuffer = ref.read(webrtcDiagBufferProvider);
    _watchEnvironment();
    _startRecoveryWindow();
    _diag('start');
    unawaited(_start(_gen));
  }

  /// 로컬 진단(메모리 버퍼 + debugPrint). 시작 때 잡아 둔다 — dispose 중엔
  /// ref를 못 읽는다.
  WebRtcDiagBuffer? _diagBuffer;

  void _diag(String event, [Map<String, Object?> data = const {}]) {
    final row = <String, Object?>{'t_ms': _timing.elapsedMilliseconds, ...data};
    debugPrint('[webrtc-timing] cam=$cameraUuid gen=$_gen $event $row');
    _diagBuffer?.add(WebRtcDiagEvent(
      at: DateTime.now(),
      cameraId: cameraUuid,
      gen: _gen,
      event: event,
      data: row,
    ));
  }

  RTCPeerConnection? _pc;
  RTCVideoRenderer? _renderer;
  String? _sessionId;

  /// 연결 때 잡아 둔 시그널링 — 정리([_cleanup])가 ref 없이 세션을 닫는다.
  WebRtcSignalingRepository? _signaling;

  /// 연결 결과 기록. 시작 때 잡아 둔다 — dispose 중엔 ref를 못 읽는다.
  WebRtcConnectLogSink? _logSink;
  _Attempt? _attempt;

  /// 현재 세대. [_restart]·[_suspend]·[dispose]가 올린다.
  int _gen = 0;
  bool _disposed = false;
  bool _isCurrent(int gen) => !_disposed && gen == _gen && !_suspended;

  // ICE 후보: sessionId 확보 전 로컬 큐
  final List<RTCIceCandidate> _pendingCandidates = [];

  // 504(카메라 무응답) 자동 재시도 1회 가드. 수동 retry()가 리셋한다.
  bool _autoRetried = false;

  // ── 자동 재연결 (2026-09-07) ──────────────────────────────────────────────
  // 라이브가 ~20분 뒤 소리 없이 죽는 일이 관측됐다. 사육장 감시 화면이
  // 수동 "다시 시도"만 갖고 있으면 안 보는 사이 끊긴 채 방치된다.
  // failed에 들어올 때마다 지수 백오프(3s→60s 상한)로 재연결한다 —
  // 컨트롤러가 autoDispose라 라이브 뷰가 화면에 있는 동안만 돈다.
  // 카메라가 오프라인으로 확인되면 멈추고 온라인이 되면 곧바로 다시 붙는다.
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  // disconnected는 일시 장애일 수 있어 WebRTC가 스스로 복구하기도 한다.
  // 유예(10초) 후에도 그대로면 failed 취급 — 안 하면 마지막 프레임이 얼어붙은
  // 채 "LIVE"로 남는다.
  Timer? _disconnectGrace;

  // 첫 프레임 대기·재생 멈춤 감시.
  Timer? _frameTimer;
  Timer? _frameDeadline;

  /// 개별 시도 전체 예산 — ICE 연결 단계엔 다른 한도가 없다.
  Timer? _attemptDeadline;

  /// 첫 프레임 뒤 30초 안정 판정 타이머.
  Timer? _stableTimer;

  /// 앱이 백그라운드에 있어 연결을 내려 둔 상태.
  bool _suspended = false;

  /// 카메라가 오프라인이라 자동 재연결을 멈춘 상태 — 온라인 신호에 재개.
  bool _waitingOnline = false;

  AppLifecycleListener? _lifecycle;

  /// 재시작이 이전 세대를 정리하는 중 — 이때 온 재시작 요청은 병합한다.
  bool _cleaningUp = false;

  // 네트워크 신호 — connectivity_plus는 같은 변화에 여러 이벤트를 낼 수 있어
  // [kWebRtcNetworkDebounce] 동안 합친 뒤 마지막 값만 반영한다.
  Timer? _netDebounce;
  String? _lastNetwork; // 마지막 신호
  String? _netApplied; // 연결에 반영한 망(기준선)
  bool _waitingNetwork = false; // 망 없음으로 재시도를 멈춘 상태

  /// 망 변경 후 프레임 진행을 기다리는 남은 틱 — 재생 감시가 소비한다.
  int? _netGraceTicks;

  bool _isNoNetwork(String? sig) =>
      sig == null || sig.isEmpty || sig == ConnectivityResult.none.name;

  void _scheduleReconnect(int gen) {
    if (!_isCurrent(gen)) return;
    _reconnectTimer?.cancel();
    if (_cameraOffline()) {
      // 꺼진 카메라에 무한히 offer를 보내 봐야 매번 15초 무응답이다.
      _waitingOnline = true;
      state = state.copyWith(
          phase: WebRtcLivePhase.failed,
          errorKey: 'crecam_live_error_camera_offline');
      _diag('wait-online');
      return;
    }
    if (_isNoNetwork(_lastNetwork) && _netApplied != null) {
      // 망 자체가 없다 — 카메라 탓으로 그리지 않고 복구 신호를 기다린다.
      _waitingNetwork = true;
      state = state.copyWith(
          phase: WebRtcLivePhase.failed,
          errorKey: 'crecam_live_error_no_network');
      _diag('wait-network');
      return;
    }
    final Duration delay;
    if (_recoveryExhausted) {
      delay = kWebRtcLowRetryInterval;
    } else {
      // 3·6·12·24·48·60초 — 지수는 5에서 멈춘다(상한 60초에 이미 도달;
      // 무한 증가시키면 pow가 언젠가 inf로 넘친다).
      delay = Duration(
          seconds: math.min(
              60, 3 * math.pow(2, math.min(5, _reconnectAttempt)).toInt()));
      _reconnectAttempt++;
    }
    _diag('reconnect-scheduled',
        {'delay_s': delay.inSeconds, 'attempt': _reconnectAttempt});
    _reconnectTimer = Timer(delay, () {
      if (!_isCurrent(gen)) return;
      // 서버 ICE 설정(TURN 자격 등)이 바뀌었을 수 있어 자동 재연결도 새로 받는다.
      ref.invalidate(webrtcConfigProvider);
      unawaited(_restart(reason: 'timer'));
    });
  }

  // ── 환경 감시 ─────────────────────────────────────────────────────────────

  void _watchEnvironment() {
    _lifecycle = AppLifecycleListener(onStateChange: (s) {
      if (s == AppLifecycleState.paused) unawaited(_suspend());
      if (s == AppLifecycleState.resumed) _resume();
    });
    // 망 신호 provider는 앱 전역에서 데워져 있다(non-autoDispose) — listen은
    // 현재 값을 다시 주지 않으므로 기준선을 직접 채운다. 안 하면 나중에 만든
    // 컨트롤러(카메라 탭·확대)가 첫 전환을 기준선으로 삼켜 재연결하지 않는다.
    final initial = ref.read(webrtcNetworkSignalProvider).valueOrNull;
    if (initial != null) {
      _lastNetwork = initial;
      if (!_isNoNetwork(initial)) _netApplied = initial;
    }
    ref.listen<AsyncValue<String>>(webrtcNetworkSignalProvider, (_, next) {
      final now = next.valueOrNull;
      if (now == null) return;
      _lastNetwork = now;
      _netDebounce?.cancel();
      _netDebounce = Timer(kWebRtcNetworkDebounce, _onNetworkSettled);
    });
    ref.listen<AsyncValue<List<TerraCamera>>>(camerasProvider, (_, next) {
      if (!_waitingOnline || _suspended || _disposed) return;
      final cam =
          next.valueOrNull?.where((c) => c.id == cameraUuid).firstOrNull;
      if (cam?.isOnline ?? false) {
        _diag('camera-online');
        _reconnectNow('camera-online');
      }
    });
  }

  bool _cameraOffline() {
    final cams = ref.read(camerasProvider).valueOrNull;
    final cam = cams?.where((c) => c.id == cameraUuid).firstOrNull;
    return cam != null && !cam.isOnline;
  }

  /// 디바운스가 끝난 망 신호 처리. 첫 값은 기준선만 잡고, 되돌아온 변화는
  /// 무시하며, 영상이 나오는 중이면 연결을 유지한 채 프레임 진행으로 판단한다.
  void _onNetworkSettled() {
    if (_suspended || _disposed) return;
    final now = _lastNetwork;
    if (_isNoNetwork(now)) {
      _diag('network-none');
      return; // 기준선은 그대로 — 돌아오면 그때 비교한다
    }
    if (_waitingNetwork) {
      _waitingNetwork = false;
      _netApplied = now;
      _diag('network-back', {'to': now});
      _reconnectNow('network-back');
      return;
    }
    if (_netApplied == null) {
      _netApplied = now;
      return;
    }
    if (now == _netApplied) return;
    final before = _netApplied;
    _netApplied = now;
    _diag('network-changed', {'from': before, 'to': now});
    if (state.phase.hasVideo) {
      // 영상이 진행 중이면 철거하지 않는다 — 감시 루프가 유예 틱 안에 프레임이
      // 안 늘면 그때 다시 붙인다.
      _netGraceTicks = kWebRtcNetworkFrameGraceTicks;
      return;
    }
    _reconnectNow('network');
  }

  /// 환경이 바뀌어 즉시 다시 붙는다(망·복귀·카메라 온라인). 백오프는
  /// 초기화하지 않는다 — 흔들리는 망에서 즉시 재시도가 무한 반복된다(A3).
  void _reconnectNow(String reason) {
    _waitingOnline = false;
    _reconnectTimer?.cancel();
    unawaited(_restart(reason: reason, force: true));
  }

  /// 백그라운드 진입 — 연결을 내린다. 화면에 안 보이는 동안 카메라 세션과
  /// 재연결 타이머를 붙잡고 있을 이유가 없고, 복귀 때 죽은 연결을 실패 판정까지
  /// 기다리지 않고 새로 붙이는 편이 빠르다.
  Future<void> _suspend() async {
    if (_suspended || _disposed) return;
    _diag('suspend');
    _suspended = true;
    _endAttempt(_gen, null);
    final gen = ++_gen;
    _cancelTimers();
    _recoveryDeadline?.cancel(); // 백그라운드 시간은 세지 않는다
    await _cleanup(closeRemote: true);
    // close 응답이 늦는 사이(최대 15~30초) 복귀해 새 세대가 재생 중일 수 있다 —
    // 그때 이 늦은 정리가 새 상태를 덮으면 영상은 흐르는데 화면은 "연결 중"에
    // 갇힌다(A1).
    if (!_disposed && _suspended && _gen == gen) {
      state = const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig);
    }
  }

  void _resume() {
    if (!_suspended || _disposed) return;
    _suspended = false;
    _diag('resume');
    // 백그라운드 동안의 망 변화는 무시했다 — 지금 붙을 망을 기준선으로 삼는다.
    // 안 하면 복귀 뒤 같은 신호의 재알림을 "변경"으로 보고 새 시도를 취소한다.
    if (!_isNoNetwork(_lastNetwork)) _netApplied = _lastNetwork;
    _startRecoveryWindow();
    _reconnectNow('resume');
  }

  // ── 공개 API ────────────────────────────────────────────────────────────────

  /// 수동 재시도 (실패 화면 버튼). 자동 재시도 가드와 config 캐시를 리셋하고,
  /// 걸려 있던 자동 재연결 백오프도 즉시 실행으로 대체한다. 오프라인 대기도
  /// 풀어 한 번은 실제로 시도한다.
  Future<void> retry() async {
    _autoRetried = false;
    _waitingOnline = false;
    _waitingNetwork = false;
    _reconnectAttempt = 0; // 사용자 의도 — 백오프를 처음부터
    _reconnectTimer?.cancel();
    _startRecoveryWindow();
    ref.invalidate(webrtcConfigProvider);
    await _restart(reason: 'manual', force: true);
  }

  /// 새 세대로 다시 붙는다. 세대를 **먼저** 올려 이전 세대의 잔여 작업을 즉시
  /// 무효로 만들고, 정리 도중 더 새로운 재시작이 오면 이쪽은 물러난다.
  ///
  /// 병합 규칙(A1): 정리 중이면 무시(이미 새 세대가 온다). 연결 시퀀스가 진행
  /// 중인데 [force]가 아니면 무시(같은 환경에서 offer를 두 번 내지 않는다).
  /// 환경이 바뀐 요청(망·복귀·수동)은 [force]로 현재 시도를 취소하고 새로 간다.
  Future<void> _restart({String reason = 'timer', bool force = false}) async {
    if (_disposed || _suspended) return;
    if (_cleaningUp || (!force && state.phase.isConnecting)) {
      _diag('restart-merged', {'reason': reason});
      return;
    }
    _diag('restart', {'reason': reason});
    _endAttempt(_gen, null);
    final gen = ++_gen;
    _cancelTimers();
    _cleaningUp = true;
    try {
      await _cleanup(closeRemote: true);
    } finally {
      _cleaningUp = false;
    }
    if (!_isCurrent(gen)) return;
    _pendingCandidates.clear();
    state = const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig);
    await _start(gen);
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _disconnectGrace?.cancel();
    _frameTimer?.cancel();
    _frameDeadline?.cancel();
    _attemptDeadline?.cancel();
    _stableTimer?.cancel();
    _netGraceTicks = null;
  }

  @override
  void dispose() {
    _endAttempt(_gen, null);
    _disposed = true;
    _gen++;
    _lifecycle?.dispose();
    _netDebounce?.cancel();
    _recoveryDeadline?.cancel();
    _cancelTimers();
    _cleanup(closeRemote: true);
    super.dispose();
  }

  // ── 연결 시퀀스 ────────────────────────────────────────────────────────────

  Future<void> _start(int gen) async {
    _attempt = _Attempt(gen, _reconnectAttempt,
        ref.read(webrtcNetworkSignalProvider).valueOrNull);
    _attemptDeadline?.cancel();
    _attemptDeadline = Timer(kWebRtcAttemptBudget, () {
      if (!_isCurrent(gen) || state.phase.hasVideo) return;
      _diag('attempt-budget-exhausted', {'phase': state.phase.name});
      _fail(gen);
    });
    try {
      await _doConnect(gen);
    } on CameraUnresponsiveException {
      if (!_isCurrent(gen)) return;
      // 504 = 서버가 3회 모두 무응답(정의상 offer_attempts=3, 백엔드 회신 §1.3).
      _attempt?.offerAttempts = 3;
      if (!_autoRetried) {
        // 펌웨어가 offer를 놓친 일시 무응답일 수 있어 1회만 자동 재시도.
        _autoRetried = true;
        _endAttempt(gen, 'unresponsive');
        await Future<void>.delayed(kWebRtcUnresponsiveRetryDelay);
        if (!_isCurrent(gen)) return;
        await _restart(reason: 'unresponsive-retry', force: true);
        return;
      }
      _fail(gen,
          outcome: 'unresponsive',
          errorKey: 'crecam_live_error_unresponsive');
    } on BackendException catch (e) {
      if (!_isCurrent(gen)) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        // 세션 복구까지 한 번 거친 뒤의 401 — 반복해 봐야 같은 답이다.
        _fail(gen, errorKey: 'crecam_live_error_auth', reconnect: false);
        return;
      }
      _diag('error', {'status': e.statusCode});
      _fail(gen);
    } catch (e) {
      if (!_isCurrent(gen)) return;
      _diag('error', {'err': e.runtimeType.toString()});
      _fail(gen);
    }
  }

  /// 이 세대를 실패로 끝낸다. 세대를 **올려** 늦게 오는 offer 응답·콜백·폴링이
  /// 실패 화면을 덮지 못하게 하고, 피어·세션·렌더러를 정리한다.
  /// [reconnect]가 false면(인증 실패) 자동 재시도 없이 버튼만 남긴다.
  void _fail(
    int gen, {
    String outcome = 'failed',
    String errorKey = 'crecam_live_error_failed',
    bool reconnect = true,
  }) {
    if (!_isCurrent(gen)) return;
    _endAttempt(gen, outcome);
    _diag('fail', {'outcome': outcome, 'phase': state.phase.name});
    _cancelTimers();
    final next = ++_gen;
    unawaited(_cleanup(closeRemote: true));
    if (!reconnect) {
      state = WebRtcLiveState(phase: WebRtcLivePhase.failed, errorKey: errorKey);
      return;
    }
    // 안정 재생으로 닫혔던 창이면 이 실패가 새 창을 연다.
    if (!_recoveryExhausted && _recoveryDeadline == null) {
      _startRecoveryWindow();
    }
    _lastErrorKey = errorKey;
    state = _recoveryExhausted
        ? WebRtcLiveState(phase: WebRtcLivePhase.failed, errorKey: errorKey)
        : const WebRtcLiveState(phase: WebRtcLivePhase.recovering);
    _scheduleReconnect(next);
  }

  // ── 집중 복구 예산(A5) ────────────────────────────────────────────────────

  /// 집중 복구 예산 창. 열려 있으면 실패는 `recovering`, 소진되면 `failed`.
  /// 진입·복귀·수동 재시도에서 열고, 안정 재생 30초에서 닫는다.
  Timer? _recoveryDeadline;
  bool _recoveryExhausted = false;

  /// recovering 중 소진되면 그때 보여 줄 사유.
  String _lastErrorKey = 'crecam_live_error_failed';

  void _startRecoveryWindow() {
    _recoveryExhausted = false;
    _recoveryDeadline?.cancel();
    _recoveryDeadline = Timer(kWebRtcRecoveryBudget, () {
      if (_disposed) return;
      _recoveryExhausted = true;
      _diag('recovery-budget-exhausted', {'phase': state.phase.name});
      if (state.phase == WebRtcLivePhase.recovering) {
        // 백오프 대기 중 — 화면을 정직하게 바꾸고, 걸려 있던 백오프 타이머를
        // 저빈도 타이머로 교체한다(_scheduleReconnect가 exhausted를 보고 60초).
        state = state.copyWith(
            phase: WebRtcLivePhase.failed, errorKey: _lastErrorKey);
        _scheduleReconnect(_gen);
      }
      // 연결 시도 중이면 그 시도가 끝날 때 _fail이 exhausted를 반영한다.
    });
  }

  void _closeRecoveryWindow() {
    _recoveryDeadline?.cancel();
    _recoveryDeadline = null;
    _recoveryExhausted = false;
  }

  // ── 연결 결과 기록 ────────────────────────────────────────────────────────

  /// 세대의 끝을 기록한다(한 번만). [outcome]이 null이면 결과 없이 끝난
  /// 것 — 재생 중이었으면 `closed`, 아니면 `cancelled`.
  void _endAttempt(int gen, String? outcome) {
    final a = _attempt;
    if (a == null || a.gen != gen || a.ended) return;
    a.ended = true;
    final playing = a.playing;
    final result = outcome ?? (playing != null ? 'closed' : 'cancelled');
    _writeLog(a, result,
        failPhase: result == 'closed' ? null : _kFailPhase[state.phase],
        streamedSec: playing?.elapsed.inSeconds);
  }

  void _writeLog(_Attempt a, String outcome,
      {String? failPhase, int? streamedSec}) {
    final sink = _logSink;
    if (sink == null) return;
    Future<void> write() async {
      (String?, String?) cands = (null, null);
      try {
        cands = await a.candidates?.timeout(const Duration(seconds: 2)) ??
            (null, null);
      } catch (_) {}
      sink(WebRtcConnectLog(
        cameraId: cameraUuid,
        outcome: outcome,
        failPhase: failPhase,
        network: a.network,
        msConfig: a.msConfig,
        msAnswer: a.msAnswer,
        msConnected: a.msConnected,
        msFirstFrame: a.msFirstFrame,
        localCand: cands.$1,
        remoteCand: cands.$2,
        reconnectAttempt: a.reconnectAttempt,
        streamedSec: streamedSec,
        offerAttempts: a.offerAttempts,
        answerMs: a.answerMs,
      ));
    }

    unawaited(write());
  }

  Future<(String?, String?)> _candidateTypes(RTCPeerConnection pc) async {
    try {
      return selectedCandidateTypes(await pc.getStats());
    } catch (_) {
      return (null, null);
    }
  }

  // ICE gathering 대기 중 srflx 후보 감지용 probe (조기 진행).
  void Function(String raw)? _iceWaitProbe;

  // 연결 단계 계측 (ms 누적): 느린 구간이 앱/펌웨어/NAT 중 어디인지 판별용.
  // 값은 세대별 [_Attempt]에 담는다(config·answer·connected·firstFrame).
  final Stopwatch _timing = Stopwatch();

  Future<void> _doConnect(int gen) async {
    _timing
      ..reset()
      ..start();
    final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);
    _signaling = signalingRepo;

    // 1+2. config(세션 캐시)와 renderer init을 병렬로
    final rendererFut = ref.read(webrtcRendererFactoryProvider)();
    Map<String, dynamic> cfg;
    try {
      cfg = await ref.read(webrtcConfigProvider.future);
    } catch (_) {
      await (await rendererFut).dispose(); // 실패 경로 native 누수 방지
      rethrow;
    }
    final renderer = await rendererFut;
    if (!_isCurrent(gen)) {
      await renderer.dispose();
      return;
    }
    _renderer = renderer;
    _attempt
      ?..msConfig = _timing.elapsedMilliseconds
      ..network ??= ref.read(webrtcNetworkSignalProvider).valueOrNull;

    // 3. PeerConnection 생성
    final pc = await ref.read(webrtcPeerConnectionFactoryProvider)({
      'iceServers': cfg['iceServers'] ?? [],
      'sdpSemantics': cfg['sdpSemantics'] ?? 'unified-plan',
    });
    if (!_isCurrent(gen)) {
      await pc.close();
      return;
    }
    _pc = pc;

    // 첫 프레임 도착 — 이때 비로소 "LIVE"다. ICE connected만으로 streaming을
    // 선언하면 키프레임을 기다리는 동안 검은 화면이 LIVE로 보였다.
    var connected = false;
    var frameSeen = false;
    renderer.onFirstFrameRendered = () {
      if (!_isCurrent(gen)) return;
      _diag('first-frame');
      frameSeen = true;
      _attempt?.msFirstFrame ??= _timing.elapsedMilliseconds;
      if (connected) _enterStreaming(gen, pc, renderer);
    };

    // 4. addTransceiver: 수신 전용 (마이크/카메라 권한 요청 없음)
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    // 5. 원격 트랙 → renderer.srcObject
    pc.onTrack = (event) {
      if (!_isCurrent(gen)) return;
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
      }
    };

    // 6. ICE 후보 수집 핸들러
    pc.onIceCandidate = (candidate) {
      if (!_isCurrent(gen)) return;
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

    // 7. 연결 상태 모니터링 — 이 세대의 피어만 본다.
    pc.onConnectionState = (s) {
      if (!_isCurrent(gen)) return;
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        final a = _attempt;
        _diag('connected', {'config_ms': a?.msConfig, 'answer_ms': a?.msAnswer});
        if (a != null && a.gen == gen && a.msConnected == null) {
          a.msConnected = _timing.elapsedMilliseconds;
          a.candidates = _candidateTypes(pc);
        }
        // 백오프는 여기서 초기화하지 않는다 — 영상이 30초 안정된 뒤에만(A3).
        _reconnectTimer?.cancel();
        _disconnectGrace?.cancel();
        if (connected) return; // disconnected에서 스스로 복구 — 감시는 그대로.
        connected = true;
        if (frameSeen) {
          _enterStreaming(gen, pc, renderer);
        } else {
          _awaitFirstFrame(gen, pc, renderer);
        }
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _fail(gen);
      } else if (s ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // 일시 장애면 WebRTC가 스스로 돌아온다 — 10초 유예 후에도 그대로면
        // failed 취급해 재연결 루프에 태운다(마지막 프레임이 얼어붙은 채
        // "LIVE"로 남는 것 방지).
        _diag('disconnected');
        _disconnectGrace?.cancel();
        _disconnectGrace = Timer(const Duration(seconds: 10), () {
          if (!_isCurrent(gen)) return;
          if (pc.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
            _fail(gen);
          }
        });
      }
    };

    // phase: offering — renderer 포함해서 전달
    if (!_isCurrent(gen)) return;
    state = WebRtcLiveState(
      phase: WebRtcLivePhase.offering,
      renderer: renderer,
    );

    // 8. createOffer → setLocalDescription
    final offerSdp = await pc.createOffer({'offerToReceiveVideo': true});
    await pc.setLocalDescription(offerSdp);

    // 9. ICE gathering 대기 — srflx 확보 시 조기 진행.
    //    나머지 후보는 answer 후 trickle(큐 flush + POST /ice)로 전송된다.
    await _waitForIceGathering(pc, maxWait: kWebRtcIceGatherWait);
    if (!_isCurrent(gen)) return;

    // 10. gathered SDP로 offer 전송
    final localDesc = await pc.getLocalDescription();
    final offerResult = await signalingRepo.sendOffer(
      cameraUuid,
      localDesc!.sdp!,
    );
    if (!_isCurrent(gen)) {
      // 기다리는 사이 새 세대로 넘어갔다 — 이 세션은 아무도 안 쓴다. 닫지 않으면
      // 펌웨어에 세션이 남아 다음 연결을 방해한다(APP_WEBRTC.md 알려진 이슈).
      unawaited(signalingRepo.closeSession(cameraUuid, offerResult.sessionId));
      return;
    }

    _sessionId = offerResult.sessionId;
    _diag('answer', {
      'session': offerResult.sessionId,
      'offer_attempts': offerResult.offerAttempts,
      'answer_ms': offerResult.answerMs,
    });
    _attempt
      ?..msAnswer = _timing.elapsedMilliseconds
      ..offerAttempts = offerResult.offerAttempts
      ..answerMs = offerResult.answerMs;

    // 11. setRemoteDescription
    await pc.setRemoteDescription(
      RTCSessionDescription(offerResult.answerSdp, 'answer'),
    );
    if (!_isCurrent(gen)) return;

    // 12. 큐에 쌓인 로컬 ICE 후보 flush
    for (final c in _pendingCandidates) {
      _sendCandidateAsync(offerResult.sessionId, c);
    }
    _pendingCandidates.clear();

    // 13. ICE 폴링 루프 시작 (백그라운드) — 이미 연결됐으면 첫 프레임 대기
    //     단계를 덮어쓰지 않는다.
    if (!connected) {
      state = state.copyWith(phase: WebRtcLivePhase.connectingIce);
    }
    unawaited(_pollIceCandidates(gen, pc, offerResult.sessionId));
  }

  // ── 첫 프레임·재생 멈춤 ────────────────────────────────────────────────────

  /// ICE는 붙었는데 아직 그림이 없다 — "영상 받는 중"으로 두고, 첫 프레임
  /// 콜백 또는 디코딩 통계로 확인한다(콜백이 안 오는 플랫폼 대비).
  void _awaitFirstFrame(int gen, RTCPeerConnection pc, RTCVideoRenderer r) {
    state = state.copyWith(phase: WebRtcLivePhase.waitingVideo, renderer: r);
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isCurrent(gen)) return;
      final frames = await _framesDecoded(pc);
      if (_isCurrent(gen) &&
          frames != null &&
          frames > 0 &&
          state.phase == WebRtcLivePhase.waitingVideo) {
        _enterStreaming(gen, pc, r);
      }
    });
    _frameDeadline?.cancel();
    _frameDeadline = Timer(kWebRtcFirstFrameTimeout, () {
      if (!_isCurrent(gen) || state.phase != WebRtcLivePhase.waitingVideo) {
        return;
      }
      debugPrint('[webrtc-timing] cam=$cameraUuid FAILED(no-video)');
      _fail(gen, outcome: 'no_video');
    });
  }

  /// 재생 시작 + 감시. 1초마다 디코딩 프레임 수를 읽어
  /// - 진행(값이 달라짐 — 증가·감소·첫 값)이면 기준을 갱신하고 `stalled`면 복귀
  /// - [kWebRtcSoftStallTicks] 연속 그대로면 `stalled`(안내만, 연결 유지)
  /// - [kWebRtcHardStallTicks] 연속 그대로면 재연결
  /// - 통계를 못 읽으면 정지도 진행도 아니다 — [kWebRtcStatsUnknownTicks] 뒤
  ///   `statsUnknown`만 켠다(겁주지 않는다)
  /// - 망 변경 유예([_netGraceTicks])는 무진행 틱에서만 줄어들고 0이면 재연결
  void _enterStreaming(int gen, RTCPeerConnection pc, RTCVideoRenderer r) {
    if (!_isCurrent(gen) || state.phase.hasVideo) return;
    _frameDeadline?.cancel();
    _attemptDeadline?.cancel();
    state = WebRtcLiveState(phase: WebRtcLivePhase.streaming, renderer: r);
    final a = _attempt;
    if (a != null && a.gen == gen && a.playing == null) {
      a.msFirstFrame ??= _timing.elapsedMilliseconds;
      a.playing = Stopwatch()..start();
      _writeLog(a, 'streaming');
    }
    _diag('streaming');
    _armStableTimer(gen);

    int? last;
    var still = 0;
    var noStats = 0;
    var busy = false;
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(kWebRtcStatsInterval, (_) async {
      if (!_isCurrent(gen) || busy) return;
      busy = true;
      final frames = await _framesDecoded(pc);
      busy = false;
      if (!_isCurrent(gen)) return;

      if (frames == null) {
        noStats++;
        if (noStats >= kWebRtcStatsUnknownTicks && !state.statsUnknown) {
          _diag('stats-unknown');
          state = state.copyWith(statsUnknown: true);
        }
        return;
      }
      noStats = 0;
      if (state.statsUnknown) state = state.copyWith(statsUnknown: false);

      if (last == null || frames != last) {
        last = frames;
        still = 0;
        _netGraceTicks = null;
        if (state.phase == WebRtcLivePhase.stalled) {
          _diag('stall-recovered');
          state = state.copyWith(phase: WebRtcLivePhase.streaming);
          _armStableTimer(gen);
        }
        return;
      }

      still++;
      final grace = _netGraceTicks;
      if (grace != null) {
        if (grace <= 1) {
          _netGraceTicks = null;
          _diag('network-no-progress');
          // 사용자 이탈(closed)이 아니라 재생 실패다 — 정지율 집계용.
          _endAttempt(gen, 'stalled');
          _reconnectNow('network');
          return;
        }
        _netGraceTicks = grace - 1;
      }
      if (still >= kWebRtcHardStallTicks) {
        _diag('stall-hard', {'still': still});
        _fail(gen, outcome: 'stalled');
        return;
      }
      if (still >= kWebRtcSoftStallTicks &&
          state.phase == WebRtcLivePhase.streaming) {
        _diag('stall-soft', {'still': still});
        _stableTimer?.cancel(); // 불안정 구간 — 안정 판정을 다시 센다
        state = state.copyWith(phase: WebRtcLivePhase.stalled);
      }
    });
  }

  /// [kWebRtcStableAfter] 동안 `streaming`이 이어지면 백오프·504 가드를
  /// 초기화한다. connected만으로 초기화하면 "영상 있음 → 즉시 실패"가 짧은
  /// 간격으로 반복돼 카메라 세션을 압박한다(A3).
  void _armStableTimer(int gen) {
    _stableTimer?.cancel();
    _stableTimer = Timer(kWebRtcStableAfter, () {
      if (!_isCurrent(gen) || state.phase != WebRtcLivePhase.streaming) return;
      _diag('stable');
      _reconnectAttempt = 0;
      _autoRetried = false;
      _closeRecoveryWindow();
    });
  }

  /// 수신 영상 디코딩 누적 프레임 수. 못 읽으면 null.
  Future<int?> _framesDecoded(RTCPeerConnection pc) async {
    try {
      final reports = await pc.getStats();
      for (final r in reports) {
        if (r.type != 'inbound-rtp') continue;
        final v = r.values;
        final kind = v['kind'] ?? v['mediaType'];
        if (kind != null && kind != 'video') continue;
        final f = v['framesDecoded'];
        if (f is num) return f.toInt();
        if (f is String) return int.tryParse(f);
      }
    } catch (_) {}
    return null;
  }

  // ── ICE gathering 대기 ────────────────────────────────────────────────────

  Future<void> _waitForIceGathering(
    RTCPeerConnection pc, {
    required Duration maxWait,
  }) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    final timer = Timer(maxWait, finish);
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

  /// 이 세대의 피어·세션에만 후보를 넣는다(세대가 바뀌면 즉시 멈춘다).
  Future<void> _pollIceCandidates(
      int gen, RTCPeerConnection pc, String sessionId) async {
    final signalingRepo = ref.read(webrtcSignalingRepositoryProvider);
    int sinceIndex = 0;

    while (_isCurrent(gen)) {
      // 계약 §4.3: connected / failed / closed 면 폴링 중단
      final pcState = pc.connectionState;
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
        if (!_isCurrent(gen)) break;

        for (final cJson in result.candidates) {
          try {
            await pc.addCandidate(
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
        if (!_isCurrent(gen)) break;
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

  /// 현재 세대의 피어·세션·렌더러 정리.
  /// [closeRemote]: true면 terra-server에 closeSession 요청
  Future<void> _cleanup({required bool closeRemote}) async {
    // 연결 때 잡아 둔 저장소를 쓴다 — dispose 경로(컨테이너 폐기 중)에선
    // ref.read 자체가 실패한다.
    final signalingRepo = _signaling;
    final sessionId = _sessionId;
    _sessionId = null;
    final pc = _pc;
    _pc = null;
    final renderer = _renderer;
    _renderer = null;

    await pc?.close();

    if (closeRemote && sessionId != null && signalingRepo != null) {
      await signalingRepo.closeSession(cameraUuid, sessionId);
    }

    await renderer?.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final webrtcLiveControllerProvider = StateNotifierProvider.autoDispose
    .family<WebRtcLiveController, WebRtcLiveState, String>(
  // 시작은 여기서 — 위젯 테스트는 startConnection() 없이 생성만 하는
  // 오버라이드로 실피어를 차단한다(클래스 doc).
  (ref, cameraUuid) => WebRtcLiveController(ref, cameraUuid)..startConnection(),
);
