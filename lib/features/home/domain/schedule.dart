/// terra-server `schedules` 테이블 매핑 — 반복 예약(PRD §4.2.2 일정).
///
/// **예약은 "명령 발행을 예약"하는 것**이다. 시각이 되면 서버가 `commands`를
/// INSERT하고, 실행·결과는 수동 제어와 똑같이 `commands`로 흐른다
/// (`APP_TIMER_MIST.md` §2.5).
///
/// ⚠️ **쓰기는 REST로만 한다.** 테이블에 RLS(`own schedules all`)가 있어 직접
/// INSERT도 통과하지만, 그러면 서버가 계산하는 `next_run_at`이 비어 예약이
/// 영영 안 돈다.
///
/// ⚠️ **PRD §4.2.2를 다 덮지 못한다.** 시작~종료 구간·스마트 조건이 계약에
/// 없어 지금은 "시점 예약"까지만이다. `docs/backend-handoff-timer-mist.md`
/// 요청 1·2 회신 대기 중.
library;

enum ScheduleKind {
  daily('daily'),
  weekly('weekly');

  const ScheduleKind(this.wire);

  final String wire;

  static ScheduleKind fromWire(String? v) =>
      v == 'weekly' ? ScheduleKind.weekly : ScheduleKind.daily;
}

/// 예약 가능한 동작.
///
/// 서버 화이트리스트 밖의 값은 400이라, **앱이 고를 수 있는 목록 자체를
/// 좁혀둔다** — 보내고 나서 거절당하는 것보다 못 고르게 하는 게 낫다.
enum ScheduleAction {
  mist('mist'),
  fanToggle('fan_toggle'),
  heaterToggle('heater_toggle'),
  ledOn('led_on'),
  ledOff('led_off'),

  /// 서버가 받긴 하지만 앱에선 안 쓴다 — 분무는 [mist]가 정공법이다.
  relayToggle('relay_toggle'),

  // ── 절대 상태 명령 ────────────────────────────────────────────────────────
  // 구간 예약("20시 켜고 23시 끄기")의 재료다. 펌웨어에는 이미 있지만
  // **`schedules` 화이트리스트에 아직 없어** 지금 만들면 400이 온다
  // (백엔드 회신 2026-08-12 · 즉시 가능 항목). 그때까지 [selectable]에서 빼둔다.
  //
  // 그래도 값을 정의해 두는 건, 웹 콘솔 등 다른 경로로 만들어진 예약이 목록에
  // 섞였을 때 `unknown`으로 뭉개지지 않게 하기 위해서다.
  fanOn('fan_on'),
  fanOff('fan_off'),
  heaterOn('heater_on'),
  heaterOff('heater_off'),
  relayOn('relay_on'),
  relayOff('relay_off'),

  /// 목록에 처음 보는 값이 섞였을 때. 한 건 때문에 화면이 통째로 비지 않도록.
  unknown('unknown');

  const ScheduleAction(this.wire);

  final String wire;

  /// 사용자가 고를 수 있는 것만. [relayToggle]·[unknown]은 뺀다.
  static const selectable = [mist, fanToggle, heaterToggle, ledOn, ledOff];

  /// `mist`는 `duration_ms`가 없으면 서버가 400을 준다.
  bool get requiresDuration => this == ScheduleAction.mist;

  /// 예약 화면에 쓰는 표시명 i18n 키.
  ///
  /// [labelKey](하드웨어 이름)와 다르다. 예약은 **동작**을 고르는 자리라
  /// `워터펌프`·`LED`처럼 부품 이름을 늘어놓으면 `조명 켜기` 옆에서 층위가
  /// 어긋난다. 켜기/끄기가 갈리는 LED도 여기서만 둘로 나뉜다.
  String get displayKey {
    switch (this) {
      case ScheduleAction.mist:
      case ScheduleAction.relayToggle:
      case ScheduleAction.relayOn:
      case ScheduleAction.relayOff:
        return 'routine_action_mist';
      case ScheduleAction.ledOn:
        return 'routine_action_led_on';
      case ScheduleAction.ledOff:
        return 'routine_action_led_off';
      case ScheduleAction.fanOn:
        return 'routine_action_fan_on';
      case ScheduleAction.fanOff:
        return 'routine_action_fan_off';
      case ScheduleAction.heaterOn:
        return 'routine_action_heater_on';
      case ScheduleAction.heaterOff:
        return 'routine_action_heater_off';
      default:
        return labelKey;
    }
  }

  /// 액추에이터 라벨 i18n 키. 기존 `module_actuator_*`를 그대로 쓴다.
  String get labelKey {
    switch (this) {
      case ScheduleAction.mist:
      case ScheduleAction.relayToggle:
      case ScheduleAction.relayOn:
      case ScheduleAction.relayOff:
        return 'module_actuator_relay';
      case ScheduleAction.fanToggle:
      case ScheduleAction.fanOn:
      case ScheduleAction.fanOff:
        return 'module_actuator_fan';
      case ScheduleAction.heaterToggle:
      case ScheduleAction.heaterOn:
      case ScheduleAction.heaterOff:
        return 'module_actuator_heater';
      case ScheduleAction.ledOn:
      case ScheduleAction.ledOff:
        return 'module_actuator_led';
      case ScheduleAction.unknown:
        return 'module_actuator_unknown';
    }
  }

  static ScheduleAction fromWire(String? v) {
    for (final a in ScheduleAction.values) {
      if (a.wire == v) return a;
    }
    return ScheduleAction.unknown;
  }
}

class Schedule {
  final String id;
  final String deviceId;
  final ScheduleAction action;
  final Map<String, dynamic>? payload;
  final ScheduleKind kind;

  /// KST 기준 시각. 서버가 `"08:00:00"`으로 내려주지만 초는 안 쓴다.
  final int hour;
  final int minute;

  /// 1=월 … 7=일. `daily`면 빈 목록.
  ///
  /// Dart `DateTime.weekday`와 같은 규칙이라 변환이 필요 없다.
  final List<int> daysOfWeek;

  final bool enabled;

  /// 다음 실행 시각. **서버는 UTC로 주고 여기서 로컬로 바꿔 보관한다.**
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;

  const Schedule({
    required this.id,
    required this.deviceId,
    required this.action,
    required this.payload,
    required this.kind,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    required this.enabled,
    required this.nextRunAt,
    required this.lastRunAt,
  });

  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  factory Schedule.fromJson(Map<String, dynamic> j) {
    final (h, m) = _parseTime(j['time_of_day'] as String?);
    final days = (j['days_of_week'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList()
        ?..sort();
    return Schedule(
      id: j['id'] as String? ?? '',
      deviceId: j['device_id'] as String? ?? '',
      action: ScheduleAction.fromWire(j['action'] as String?),
      payload: j['payload'] is Map
          ? (j['payload'] as Map).cast<String, dynamic>()
          : null,
      kind: ScheduleKind.fromWire(j['kind'] as String?),
      hour: h,
      minute: m,
      daysOfWeek: days ?? const [],
      enabled: j['enabled'] as bool? ?? true,
      nextRunAt: _parseLocal(j['next_run_at']),
      lastRunAt: _parseLocal(j['last_run_at']),
    );
  }

  /// 생성 요청 본문.
  ///
  /// **없는 값은 키째로 뺀다.** `null`을 실어 보내면 서버 검증에 걸릴 수 있고,
  /// PATCH에서는 "안 바꿈"과 "비움"이 구분되지 않는다.
  static Map<String, dynamic> createBody({
    required ScheduleAction action,
    required ScheduleKind kind,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    Map<String, dynamic>? payload,
  }) {
    final sorted = [...daysOfWeek]..sort();
    return {
      'action': action.wire,
      'kind': kind.wire,
      'time_of_day':
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      if (kind == ScheduleKind.weekly) 'days_of_week': sorted,
      if (payload != null) 'payload': payload,
    };
  }

  /// 서버에 보내기 전 최소 검증. `weekly`인데 요일이 비면 400이다.
  static bool validate({
    required ScheduleKind kind,
    required List<int> daysOfWeek,
  }) =>
      kind == ScheduleKind.daily || daysOfWeek.isNotEmpty;

  Schedule copyWith({bool? enabled}) => Schedule(
        id: id,
        deviceId: deviceId,
        action: action,
        payload: payload,
        kind: kind,
        hour: hour,
        minute: minute,
        daysOfWeek: daysOfWeek,
        enabled: enabled ?? this.enabled,
        nextRunAt: nextRunAt,
        lastRunAt: lastRunAt,
      );

  static (int, int) _parseTime(String? v) {
    if (v == null) return (0, 0);
    final parts = v.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return (h, m);
  }

  /// UTC 문자열 → 로컬 [DateTime].
  ///
  /// 문서(§2.1) 예제는 `.toUtc().add(Duration(hours: 9))`인데, 결과가 `isUtc`인
  /// 채 +9가 되어 이후 `toLocal()`을 또 부르면 이중 변환된다. `toLocal()`
  /// 하나면 끝이고, 기기 타임존이 KST가 아닐 때도 맞다.
  static DateTime? _parseLocal(Object? v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
