/// 차트에 찍는 기기 동작 종류. PRD §3.4 "분무(💦), 팬(🔵), 히터(🔥), LED(💡)".
enum MarkerKind { mist, fan, heater, led }

/// PRD §3.4 기기 동작 마커.
///
/// 데이터 소스는 **`commands` 테이블**이다. `telemetry_30m`은 30분 집계라
/// 액추에이터 전이 시점을 담지 못하므로, 실제로 언제 동작했는지 아는 유일한
/// 기록이 명령 이력이다. `status='acked'`(기기가 받아 실행)만 마커가 된다 —
/// 거부/대기 중인 명령을 동작으로 그리면 사용자가 오해한다.
class ActuatorMarker {
  final MarkerKind kind;
  final DateTime at;

  const ActuatorMarker({required this.kind, required this.at});

  /// [start]~[end] 구간에서의 0.0~1.0 위치. 구간 밖이거나 길이가 0이면 null.
  double? positionIn({required DateTime start, required DateTime end}) {
    final span = end.difference(start).inMilliseconds;
    if (span <= 0) return null;
    if (at.isBefore(start) || at.isAfter(end)) return null;
    return at.difference(start).inMilliseconds / span;
  }

  static const _kindByAction = {
    'mist': MarkerKind.mist,
    // 2026-08-12 `mist` 계약이 생기기 전까지 분무는 전부 이걸로 나갔다
    // (실DB 144건). 새 것만 매핑하면 그 이력이 차트에서 조용히 사라진다.
    'relay_toggle': MarkerKind.mist,
    'fan_toggle': MarkerKind.fan,
    'heater_toggle': MarkerKind.heater,
    'led_on': MarkerKind.led,
    'led_off': MarkerKind.led,
    // 켜고 끄는 동작은 전부 같은 뜻이다. 빠뜨리면 그 시각에 조명이 돈 기록만
    // 조용히 사라진다(DB에 12건 있었다).
    'led_toggle': MarkerKind.led,
  };

  /// `commands` 행 목록 → 시간순 마커 목록.
  static List<ActuatorMarker> fromCommands(List<Map<String, dynamic>> rows) {
    final out = <ActuatorMarker>[];
    for (final r in rows) {
      if (r['status'] != 'acked') continue;
      final kind = _kindByAction[r['action'] as String?];
      if (kind == null) continue;
      final at = r['issued_at'] == null
          ? null
          : DateTime.tryParse(r['issued_at'].toString());
      if (at == null) continue;
      out.add(ActuatorMarker(kind: kind, at: at));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
