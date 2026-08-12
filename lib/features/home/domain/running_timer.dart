/// PRD §4.2.1 진행 중 타이머 칩의 데이터 모델.
///
/// **아직 이걸 채울 데이터가 없다.** 2026-08-12 일회성 타이머를 A안
/// (`fan_on` + `duration_ms`, 펌웨어가 스스로 OFF)으로 정하면서, 한때 가정했던
/// `device_timers` 테이블은 만들어지지 않는다. A안이 열리면 `commands` 이력에서
/// `issued_at + duration_ms`로 [endsAt]을 계산해 채운다.
///
/// [fromJson]은 그 시절 스키마를 그대로 두었다 — A안 배선 때 어느 쪽이든
/// 맞춰 쓰면 되고, 포맷·만료 로직은 데이터 출처와 무관하게 여기서 검증된다.
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
