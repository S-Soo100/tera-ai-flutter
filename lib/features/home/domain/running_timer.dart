/// PRD §3.4 진행 중 타이머 칩의 데이터 모델.
///
/// 백엔드 `device_timers` 테이블(BE4)이 아직 없다 — 그 전까지 조회는 항상 빈
/// 목록이고 칩은 뜨지 않는다. 포맷·만료 로직은 그와 무관하게 여기서 검증된다.
class RunningTimer {
  final String id;
  final String deviceId;

  /// 액추에이터 i18n 키. 기존 `module_actuator_*` 키를 그대로 쓴다.
  final String actuatorLabelKey;

  /// 사용자가 건 타이머 길이(분). 칩 문구 `팬 30분 타이머 가동 중`의 30.
  final int durationMinutes;

  final DateTime endsAt;

  const RunningTimer({
    required this.id,
    required this.deviceId,
    required this.actuatorLabelKey,
    required this.durationMinutes,
    required this.endsAt,
  });

  /// 남은 시간. 만료됐으면 [Duration.zero] — 음수 카운트다운을 막는다.
  Duration remaining(DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool isActive(DateTime now) => remaining(now) > Duration.zero;

  factory RunningTimer.fromJson(Map<String, dynamic> j) {
    return RunningTimer(
      id: j['id'] as String? ?? '',
      deviceId: j['device_id'] as String? ?? '',
      actuatorLabelKey: _labelKey(j['actuator'] as String?),
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
      endsAt: j['ends_at'] != null
          ? DateTime.tryParse(j['ends_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  static String _labelKey(String? actuator) {
    const known = {'fan', 'heater', 'led', 'relay'};
    return known.contains(actuator)
        ? 'module_actuator_$actuator'
        : 'module_actuator_unknown';
  }
}

/// `18분 20초` / `7초` / `1시간 5분 3초` 형식. PRD 목업 문구를 따른다.
String formatRemaining(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h시간 $m분 $s초';
  if (m > 0) return '$m분 $s초';
  return '$s초';
}
