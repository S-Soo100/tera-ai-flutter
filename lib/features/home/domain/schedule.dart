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
/// 시작~종료 구간은 on/off 예약 **2건**에 같은 [pairId]를 실어 만든다 —
/// 서버가 짝을 묶어 한쪽을 지우면 다른 쪽도 지운다(2026-08-18 회신 §3,
/// `docs/backend-reply-2026-08-18-app-delivery.md`). 스마트 조건은
/// [ScheduleGuard](스킵형 4종)로 건다(2026-08-14 핸드오프 §2).
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
  // 구간 예약("20시 켜고 23시 끄기")의 재료다. 2026-08-14 핸드오프로
  // `schedules` 화이트리스트에 들어와 [selectable]에도 올랐다(§2.1).
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

  /// 사용자가 고를 수 있는 것만. toggle 계열은 뺀다 — 예약은 무인 실행이라
  /// 기기 상태가 한 번 어긋나면 뒤집기가 반대로 동작한다(히터면 과열이다).
  /// [relayOn]/[relayOff]도 뺀다 — 분무는 [mist]가 정공법.
  static const selectable = [
    mist,
    fanOn,
    fanOff,
    heaterOn,
    heaterOff,
    ledOn,
    ledOff,
  ];

  /// `mist`는 `duration_ms`가 없으면 서버가 400을 준다.
  bool get requiresDuration => this == ScheduleAction.mist;

  /// 끄기 계열인가. **끄기 예약에는 가드를 걸 수 없다** — 조건 때문에 끄기가
  /// 건너뛰어지면 기기가 켜진 채 남는다(히터면 과열). 편집기·삭제 경고가 쓴다.
  bool get isOffAction =>
      this == ScheduleAction.fanOff ||
      this == ScheduleAction.heaterOff ||
      this == ScheduleAction.ledOff ||
      this == ScheduleAction.relayOff;

  /// 끄기 동작의 짝이 되는 켜기 동작. 끄기 계열이 아니면 null.
  ScheduleAction? get onCounterpart {
    switch (this) {
      case ScheduleAction.fanOff:
        return ScheduleAction.fanOn;
      case ScheduleAction.heaterOff:
        return ScheduleAction.heaterOn;
      case ScheduleAction.ledOff:
        return ScheduleAction.ledOn;
      case ScheduleAction.relayOff:
        return ScheduleAction.relayOn;
      default:
        return null;
    }
  }

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

/// 스마트 가드 조건 종류 — 서버가 예약 발행 직전 평가해 **스킵**한다
/// (`docs/backend-handoff-2026-08-14-summary.md` §2.3).
///
/// 정지형(가동 중 정지, 예: 히터 목표온도 도달 시 OFF)은 펌웨어 담당
/// 미구현이라 여기 없다. 값이 추가되면 [ScheduleGuard.fromJson]의 null 반환
/// 경로도 같이 보라.
enum GuardType {
  humidityAbove('skip_when_humidity_above'),
  humidityBelow('skip_when_humidity_below'),
  tempAbove('skip_when_temp_above'),
  tempBelow('skip_when_temp_below');

  const GuardType(this.wire);

  final String wire;

  /// 편집기 단위 표기(%·°C)와 입력 범위가 갈린다.
  bool get isHumidity =>
      this == GuardType.humidityAbove || this == GuardType.humidityBelow;

  static GuardType? fromWire(String? v) {
    for (final t in GuardType.values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// 예약의 스마트 조건. 서버 JSON `{type, value, enabled}` 그대로.
class ScheduleGuard {
  final GuardType type;
  final double value;
  final bool enabled;

  const ScheduleGuard({
    required this.type,
    required this.value,
    required this.enabled,
  });

  Map<String, dynamic> toJson() =>
      {'type': type.wire, 'value': value, 'enabled': enabled};

  /// 모르는 type이면 null — 한 예약의 가드 때문에 목록이 통째로 비지 않게.
  /// (수정 시 guard 키를 생략하면 서버 값이 유지되므로 유실은 없다.)
  static ScheduleGuard? fromJson(Object? j) {
    if (j is! Map) return null;
    final type = GuardType.fromWire(j['type'] as String?);
    final value = (j['value'] as num?)?.toDouble();
    if (type == null || value == null) return null;
    return ScheduleGuard(
      type: type,
      value: value,
      enabled: j['enabled'] as bool? ?? true,
    );
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

  /// 스마트 조건. 없거나 서버가 모르는 형태면 null.
  final ScheduleGuard? guard;

  /// 구간 예약의 짝 식별자(앱 생성 UUID). on/off 두 행이 같은 값을 갖는다.
  /// 시점 예약·2026-08-18 이전에 만든 구간(낱개 2건)은 null.
  final String? pairId;

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
    this.guard,
    this.pairId,
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
      guard: ScheduleGuard.fromJson(j['guard']),
      pairId: j['pair_id'] as String?,
      nextRunAt: _parseLocal(j['next_run_at']),
      lastRunAt: _parseLocal(j['last_run_at']),
    );
  }

  /// 목록을 **구간 한 줄**로 묶는다. 같은 [pairId]를 가진 on/off를 [SchedulePair]로,
  /// 나머지(시점·짝 없는 낱개)는 그대로 돌려준다. 순서는 원본 첫 등장 순.
  ///
  /// 짝이 한쪽만 남았거나(서버가 짝 삭제를 보장하지만 웹 콘솔 직접 삭제 등)
  /// 두 행이 다 켜기/다 끄기면 묶지 않고 낱개로 둔다 — 억지로 묶어 그리면
  /// 삭제·토글이 어느 행에 걸리는지 사용자가 알 수 없다.
  static List<Object> group(List<Schedule> list) {
    final byPair = <String, List<Schedule>>{};
    for (final s in list) {
      if (s.pairId != null) byPair.putIfAbsent(s.pairId!, () => []).add(s);
    }
    final out = <Object>[];
    final emitted = <String>{};
    for (final s in list) {
      final pid = s.pairId;
      if (pid == null) {
        out.add(s);
        continue;
      }
      if (emitted.contains(pid)) continue;
      final legs = byPair[pid]!;
      final on = legs.where((e) => !e.action.isOffAction).firstOrNull;
      final off = legs.where((e) => e.action.isOffAction).firstOrNull;
      if (legs.length == 2 && on != null && off != null) {
        out.add(SchedulePair(on: on, off: off));
      } else {
        out.addAll(legs);
      }
      emitted.add(pid);
    }
    return out;
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
    ScheduleGuard? guard,
    String? pairId,
  }) {
    final sorted = [...daysOfWeek]..sort();
    return {
      'action': action.wire,
      'kind': kind.wire,
      'time_of_day':
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      if (kind == ScheduleKind.weekly) 'days_of_week': sorted,
      if (payload != null) 'payload': payload,
      if (guard != null) 'guard': guard.toJson(),
      if (pairId != null) 'pair_id': pairId,
    };
  }

  /// 서버에 보내기 전 최소 검증. `weekly`인데 요일이 비면 400이다.
  static bool validate({
    required ScheduleKind kind,
    required List<int> daysOfWeek,
  }) =>
      kind == ScheduleKind.daily || daysOfWeek.isNotEmpty;

  /// 구간이 자정을 넘는가 — 종료가 시작과 같거나 이르면 **다음날 종료**로 해석한다.
  static bool spanCrossesMidnight({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) =>
      endHour < startHour ||
      (endHour == startHour && endMinute <= startMinute);

  /// 구간 예약 off쪽의 요일.
  ///
  /// **weekly + 자정 넘김이면 하루씩 민다**(월→화 … 일→월). 안 밀면 off가
  /// 같은 요일 새벽에 걸려 **그 주의 on보다 먼저** 발화하고, 밤에 켜진 기기는
  /// 다음 주까지 꺼지지 않는다 — 히터면 ~6일 무인 가동이다. daily는 매일
  /// 돌아서 그대로 자연스럽다.
  static List<int> offLegDays({
    required ScheduleKind kind,
    required List<int> daysOfWeek,
    required bool crossesMidnight,
  }) {
    if (kind != ScheduleKind.weekly || !crossesMidnight) return daysOfWeek;
    return (daysOfWeek.map((d) => d % 7 + 1).toList())..sort();
  }

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
        guard: guard,
        pairId: pairId,
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

/// 구간 예약 한 줄 — 같은 `pair_id`의 켜기/끄기 행. [Schedule.group]이 만든다.
class SchedulePair {
  final Schedule on;
  final Schedule off;

  const SchedulePair({required this.on, required this.off});

  String get pairId => on.pairId!;

  /// 두 행이 모두 켜져 있을 때만 "켜짐". 한쪽만 꺼진 상태(웹 콘솔 등)는
  /// 목록에서 꺼짐으로 보이고, 토글을 켜면 둘 다 켜져 정상으로 돌아온다.
  bool get enabled => on.enabled && off.enabled;

  ScheduleKind get kind => on.kind;
  List<int> get daysOfWeek => on.daysOfWeek;
  ScheduleGuard? get guard => on.guard;
}
