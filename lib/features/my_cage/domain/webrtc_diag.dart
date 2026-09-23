import 'dart:collection';

/// 라이브 연결 진단 이벤트 한 건(앱 로컬, 2026-09-23).
///
/// 원격 `webrtc_connect_logs`는 세대당 결과 1~2행뿐이라 "왜 재연결했는지"를
/// 못 담는다. 이 버퍼는 전환 사유(수동·네트워크·복귀·정지·병합)를 순서대로
/// 남겨 펌웨어·서버 로그와 대조하기 위한 것이다. 후보 값·SDP·JWT·TURN 자격은
/// 넣지 않는다 — 넣는 쪽이 책임진다.
class WebRtcDiagEvent {
  const WebRtcDiagEvent({
    required this.at,
    required this.cameraId,
    required this.gen,
    required this.event,
    this.data = const {},
  });

  final DateTime at;
  final String cameraId;
  final int gen;
  final String event;
  final Map<String, Object?> data;

  String toLine() {
    final cam = cameraId.length > 8 ? cameraId.substring(0, 8) : cameraId;
    final kv = data.entries.map((e) => '${e.key}=${e.value}').join(' ');
    return '${at.toUtc().toIso8601String()} cam=$cam gen=$gen $event'
        '${kv.isEmpty ? '' : ' $kv'}';
  }
}

/// 최근 [capacity]건만 남기는 순환 버퍼. 메모리 전용 — 강제 종료면 사라진다
/// (기획서 §6 한계로 명시).
class WebRtcDiagBuffer {
  WebRtcDiagBuffer({this.capacity = 600});

  final int capacity;
  final ListQueue<WebRtcDiagEvent> _q = ListQueue();

  List<WebRtcDiagEvent> get events => List.unmodifiable(_q);

  void add(WebRtcDiagEvent e) {
    if (_q.length >= capacity) _q.removeFirst();
    _q.addLast(e);
  }

  void clear() => _q.clear();

  String export({String? header}) => [
        if (header != null) header,
        ..._q.map((e) => e.toLine()),
      ].join('\n');
}
