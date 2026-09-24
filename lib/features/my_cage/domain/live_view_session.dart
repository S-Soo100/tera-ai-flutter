/// 라이브 시청 세션(view) 집계 — `webrtc_view_logs`(2026-09-25).
///
/// `webrtc_connect_logs`는 연결 1회(세대) 단위라 "유저가 화면을 열어 결국
/// 영상을 봤나·몇 초 기다렸나·실패 화면을 얼마나 봤나"를 못 답한다. view는
/// 앱 전경에서 한 카메라 라이브를 연속으로 띄운 구간(시작·복귀 → 이탈·백그라운드)
/// 이고, 끝날 때 요약 1행을 남긴다. 기획
/// `docs/superpowers/specs/2026-09-25-live-view-session-logging-design.md`.
///
/// 순수 집계만 한다 — 기록 전송은 컨트롤러의 sink가 맡는다.
library;

import 'package:clock/clock.dart';

/// 화면 상태를 시간 집계용 5칸으로 접는다(컨트롤러의 phase → bucket).
enum LiveViewBucket { connecting, video, stalled, recovering, failed }

enum LiveViewEnd { closed, background }

class LiveViewSession {
  LiveViewSession({
    required this.viewId,
    required this.cameraId,
    this.firmwareVer,
    this.network,
    this.cameraOnline,
    DateTime Function()? clock,
    Stopwatch Function()? stopwatch,
  })  : startedAt = (clock ?? _now)(),
        _watch = (stopwatch ?? _monotonic)()..start();

  // package:clock — 위젯 테스트의 가짜 시계를 따른다(DateTime.now는 안 흐른다).
  static DateTime _now() => clock.now();

  /// 경과 시간은 **단조 시계**로 잰다 — 벽시계 차이는 NTP 보정·시간 변경으로
  /// 음수가 되고 DB CHECK(`duration_ms >= 0`)에 행 전체가 거부된다(리뷰
  /// 2026-09-25). 네이티브 Stopwatch는 가짜 시계를 따르지 않아, 위젯 테스트가
  /// 가짜 시계를 걸었을 때만 그 시계 기반 스톱워치를 쓴다.
  static Stopwatch _monotonic() =>
      identical(clock, const Clock()) ? Stopwatch() : clock.stopwatch();

  final String viewId;
  final String cameraId;
  String? firmwareVer;
  String? network;
  bool? cameraOnline;
  /// 시작 벽시계 시각 — DB `started_at` 표기용. 경과 계산에는 쓰지 않는다.
  final DateTime startedAt;
  final Stopwatch _watch;

  /// 시작 때 몰랐던 환경값만 채운다(카메라 목록·망 신호가 늦게 오는 경우).
  /// 이미 있는 값은 덮지 않는다 — "시작 시점" 값이 기준이다.
  void fillEnv({String? firmwareVer, String? network, bool? cameraOnline}) {
    this.firmwareVer ??= firmwareVer;
    this.network ??= network;
    this.cameraOnline ??= cameraOnline;
  }

  final Map<LiveViewBucket, int> _ms = {};
  final Map<String, int> _restarts = {};
  LiveViewBucket? _bucket;
  int? _since; // 현재 칸에 들어온 경과 ms
  int? _firstVideoMs;
  int _attempts = 0;
  int _stallCount = 0;
  int _failedCount = 0;
  int _manualRetries = 0;
  bool _finished = false;

  int _elapsed() => _watch.elapsedMilliseconds;

  void _close(int at) {
    final b = _bucket;
    final since = _since;
    if (b == null || since == null) return;
    _ms[b] = (_ms[b] ?? 0) + (at - since);
  }

  /// 화면 상태 변화. 같은 칸 재통지는 무시한다(진입 횟수를 늘리지 않는다).
  void onPhase(LiveViewBucket bucket) {
    if (_finished || bucket == _bucket) return;
    final at = _elapsed();
    _close(at);
    _bucket = bucket;
    _since = at;
    if (bucket == LiveViewBucket.video) _firstVideoMs ??= at;
    if (bucket == LiveViewBucket.stalled) _stallCount++;
    if (bucket == LiveViewBucket.failed) _failedCount++;
  }

  /// 연결 시도(세대) 시작.
  void onAttempt() {
    if (!_finished) _attempts++;
  }

  /// 실제로 수행된 재연결의 사유(`network`·`timer`·`manual`·`resume` 등).
  void onRestart(String reason) {
    if (!_finished) _restarts[reason] = (_restarts[reason] ?? 0) + 1;
  }

  /// 유저가 "다시 연결"을 눌렀다(재시작이 병합돼도 센다).
  void onManualRetry() {
    if (!_finished) _manualRetries++;
  }

  /// view를 닫고 요약을 낸다. 두 번째부터는 null.
  LiveViewSummary? finish(LiveViewEnd end) {
    if (_finished) return null;
    _finished = true;
    final at = _elapsed();
    _watch.stop();
    _close(at);
    return LiveViewSummary(
      viewId: viewId,
      cameraId: cameraId,
      startedAt: startedAt,
      firmwareVer: firmwareVer,
      network: network,
      cameraOnline: cameraOnline,
      endReason: end,
      durationMs: at,
      firstVideoMs: _firstVideoMs,
      attempts: _attempts,
      msConnecting: _ms[LiveViewBucket.connecting] ?? 0,
      msVideo: _ms[LiveViewBucket.video] ?? 0,
      msStalled: _ms[LiveViewBucket.stalled] ?? 0,
      msRecovering: _ms[LiveViewBucket.recovering] ?? 0,
      msFailed: _ms[LiveViewBucket.failed] ?? 0,
      stallCount: _stallCount,
      failedCount: _failedCount,
      manualRetries: _manualRetries,
      restarts: Map.unmodifiable(_restarts),
    );
  }
}

class LiveViewSummary {
  const LiveViewSummary({
    required this.viewId,
    required this.cameraId,
    required this.startedAt,
    this.firmwareVer,
    this.network,
    this.cameraOnline,
    required this.endReason,
    required this.durationMs,
    this.firstVideoMs,
    required this.attempts,
    required this.msConnecting,
    required this.msVideo,
    required this.msStalled,
    required this.msRecovering,
    required this.msFailed,
    required this.stallCount,
    required this.failedCount,
    required this.manualRetries,
    required this.restarts,
  });

  final String viewId;
  final String cameraId;
  final DateTime startedAt;
  final String? firmwareVer;
  final String? network;
  final bool? cameraOnline;
  final LiveViewEnd endReason;
  final int durationMs;

  /// 시작→첫 영상. null = 이 view에서 끝내 영상을 못 봤다.
  final int? firstVideoMs;
  final int attempts;
  final int msConnecting;
  final int msVideo;
  final int msStalled;
  final int msRecovering;
  final int msFailed;
  final int stallCount;
  final int failedCount;
  final int manualRetries;
  final Map<String, int> restarts;

  /// `user_id`는 DB 기본값(auth.uid())이 채운다. null 필드는 보내지 않는다.
  Map<String, dynamic> toRow({String? appVersion, String? platform}) {
    final row = <String, dynamic>{
      'view_id': viewId,
      'camera_id': cameraId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'app_version': appVersion,
      'platform': platform,
      'network': network,
      'firmware_ver': firmwareVer,
      'camera_online': cameraOnline,
      'end_reason': endReason.name,
      'duration_ms': durationMs,
      'first_video_ms': firstVideoMs,
      'attempts': attempts,
      'ms_connecting': msConnecting,
      'ms_video': msVideo,
      'ms_stalled': msStalled,
      'ms_recovering': msRecovering,
      'ms_failed': msFailed,
      'stall_count': stallCount,
      'failed_count': failedCount,
      'manual_retries': manualRetries,
      'restarts': restarts,
    };
    row.removeWhere((_, v) => v == null);
    return row;
  }
}
