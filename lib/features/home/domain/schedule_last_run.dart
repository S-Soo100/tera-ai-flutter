/// 예약의 마지막 실행 결과(2026-09-25).
///
/// 예약은 서버가 실행해서 앱은 결과를 몰랐고, 예약 시각 로컬 알림은 결과와
/// 상관없이 "실행돼요"라고 했다(운영: 최근 5일 예약 명령 약 20건이 기기
/// 무응답). 서버는 예약이 낸 명령에 `source='schedule'`·`source_id=예약 id`를
/// 남긴다 — 그 최신 행으로 목록에 결과를 붙인다.
class ScheduleLastRun {
  const ScheduleLastRun(
      {required this.issuedAt, required this.status, required this.result});

  final DateTime issuedAt;
  final String? status;
  final String? result;

  /// 실패 사유 문구 키. 성공·확인 중이면 null.
  String? get failureKey => switch (status) {
        'acked' => switch (result) {
            'ok' => null,
            'busy' => 'schedule_run_busy',
            _ => 'schedule_run_rejected',
          },
        'rejected' => 'schedule_run_rejected',
        'no_ack' || 'expired' || 'lost' => 'schedule_run_no_ack',
        _ => null,
      };

  /// 아직 결과가 없다(pending/sent).
  bool get pending => status == 'pending' || status == 'sent';
}

/// 예약 id별 최신 실행. [rows]는 `commands` 행(`source_id`·`status`·`result`·
/// `issued_at`), 순서는 상관없다.
Map<String, ScheduleLastRun> latestScheduleRuns(
    Iterable<Map<String, Object?>> rows) {
  final out = <String, ScheduleLastRun>{};
  for (final row in rows) {
    final id = row['source_id'];
    final at = DateTime.tryParse('${row['issued_at']}');
    if (id is! String || at == null) continue;
    final prev = out[id];
    if (prev != null && !at.isAfter(prev.issuedAt)) continue;
    out[id] = ScheduleLastRun(
        issuedAt: at,
        status: row['status'] as String?,
        result: row['result'] as String?);
  }
  return out;
}

/// 여러 예약(구간 예약의 켜기·끄기) 중 가장 최근 실행.
ScheduleLastRun? latestOf(
    Map<String, ScheduleLastRun> runs, Iterable<String> scheduleIds) {
  ScheduleLastRun? best;
  for (final id in scheduleIds) {
    final r = runs[id];
    if (r != null && (best == null || r.issuedAt.isAfter(best.issuedAt))) {
      best = r;
    }
  }
  return best;
}
