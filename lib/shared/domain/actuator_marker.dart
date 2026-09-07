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

  /// **켜기·끄기·뒤집기를 전부 같은 종류로 본다.** 마커는 "그 시각에 이 기기가
  /// 움직였다"는 뜻이지 방향이 아니다.
  ///
  /// ⚠️ 새 명령을 추가할 때 여기를 같이 고치지 않으면 **그 동작만 차트에서
  /// 조용히 사라진다.** 에러도 안 난다. `led_toggle`을 빠뜨려 12건이 안 보였고,
  /// `mist` 전환 때도 같은 함정을 밟을 뻔했다.
  ///
  /// `lcd_bitmap`/`lcd_clear`는 **의도적으로 없다** — 화면 표시는 기기
  /// 동작(액추에이터 전이)이 아니라서 차트 마커가 아니다.
  static const _kindByAction = {
    // 분무: `mist`(정량) · `relay_*`(수동 토글). 2026-08-12 이전 이력 144건이
    // 전부 `relay_toggle`이라 새 것만 매핑하면 과거가 통째로 증발한다.
    'mist': MarkerKind.mist,
    'relay_toggle': MarkerKind.mist,
    'relay_on': MarkerKind.mist,
    'relay_off': MarkerKind.mist,

    'fan_toggle': MarkerKind.fan,
    'fan_on': MarkerKind.fan,
    'fan_off': MarkerKind.fan,

    'heater_toggle': MarkerKind.heater,
    'heater_on': MarkerKind.heater,
    'heater_off': MarkerKind.heater,

    'led_on': MarkerKind.led,
    'led_off': MarkerKind.led,
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
