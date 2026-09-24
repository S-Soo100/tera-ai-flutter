import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 라이브 연결 결과 1행 — `webrtc_connect_logs`(2026-09-23 운영 적용).
///
/// 연결 한 번(세대)이 결과를 내면 1행, 재생하던 연결이 끝나면 1행 더 쓴다:
/// - 결과 행: `streaming`(첫 프레임 도착) / `failed` / `unresponsive`(504) /
///   `no_video`(연결 후 30초 무영상) / `cancelled`(결과 전 재연결·백그라운드·이탈)
/// - 재생 종료 행: `stalled`(15초 정지) / `failed`(재생 중 ICE 실패) /
///   `closed`(화면 이탈·백그라운드) — `fail_phase=streaming`, `streamed_sec` 포함
///
/// 성공 행을 끝날 때가 아니라 **첫 프레임 즉시** 쓰는 이유: 앱이 강제 종료되면
/// 종료 행은 안 남는다. 성공이 빠지면 실패율이 부풀려진다.
/// 성공률 = `streaming` ÷ (`streaming` + fail_phase가 streaming이 아닌 실패).
class WebRtcConnectLog {
  const WebRtcConnectLog({
    required this.cameraId,
    required this.outcome,
    this.failPhase,
    this.network,
    this.msConfig,
    this.msAnswer,
    this.msConnected,
    this.msFirstFrame,
    this.localCand,
    this.remoteCand,
    this.reconnectAttempt,
    this.streamedSec,
    this.offerAttempts,
    this.answerMs,
    this.viewId,
    this.firmwareVer,
  });

  final String cameraId;
  final String outcome;
  final String? failPhase;
  final String? network;
  final int? msConfig;
  final int? msAnswer;
  final int? msConnected;
  final int? msFirstFrame;
  final String? localCand;
  final String? remoteCand;
  final int? reconnectAttempt;
  final int? streamedSec;
  final int? offerAttempts;
  final int? answerMs;

  /// 소속 시청 세션(`webrtc_view_logs.view_id`, 2026-09-25).
  final String? viewId;

  /// 시도 시점의 카메라 펌웨어 버전.
  final String? firmwareVer;

  /// `user_id`는 DB 기본값(auth.uid())이 채운다. null 필드는 보내지 않는다.
  Map<String, dynamic> toRow({String? appVersion, String? platform}) {
    final row = <String, dynamic>{
      'camera_id': cameraId,
      'outcome': outcome,
      'fail_phase': failPhase,
      'network': network,
      'app_version': appVersion,
      'platform': platform,
      'ms_config': msConfig,
      'ms_answer': msAnswer,
      'ms_connected': msConnected,
      'ms_first_frame': msFirstFrame,
      'local_cand': localCand,
      'remote_cand': remoteCand,
      'reconnect_attempt': reconnectAttempt,
      'streamed_sec': streamedSec,
      'offer_attempts': offerAttempts,
      'answer_ms': answerMs,
      'view_id': viewId,
      'firmware_ver': firmwareVer,
    };
    row.removeWhere((_, v) => v == null);
    return row;
  }
}

/// DB CHECK가 허용하는 후보 타입(W3C RTCIceCandidateType). 그 밖의 값을
/// 보내면 행 전체가 거부되므로 null로 바꾼다.
const kIceCandidateTypes = {'host', 'srflx', 'prflx', 'relay'};

/// getStats에서 실제로 선택된 후보 쌍의 (로컬, 원격) 타입.
/// transport의 selectedCandidatePairId를 먼저 보고, 없으면(플랫폼마다 다름)
/// selected 또는 nominated+succeeded인 candidate-pair를 쓴다.
(String?, String?) selectedCandidateTypes(List<StatsReport> reports) {
  final byId = {for (final r in reports) r.id: r};
  bool yes(Object? v) => v == true || v == 'true';

  StatsReport? pair;
  for (final r in reports) {
    if (r.type != 'transport') continue;
    final id = r.values['selectedCandidatePairId'];
    if (id is String) pair = byId[id];
    if (pair != null) break;
  }
  pair ??= reports
      .where((r) =>
          r.type == 'candidate-pair' &&
          (yes(r.values['selected']) ||
              (yes(r.values['nominated']) &&
                  r.values['state'] == 'succeeded')))
      .firstOrNull;
  if (pair == null) return (null, null);

  String? typeOf(Object? id) {
    final t = byId[id]?.values['candidateType'];
    return kIceCandidateTypes.contains(t) ? t as String : null;
  }

  return (
    typeOf(pair.values['localCandidateId']),
    typeOf(pair.values['remoteCandidateId']),
  );
}
