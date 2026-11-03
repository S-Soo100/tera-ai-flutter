import 'dart:convert';

/// 모듈 화면(LCD) 설정 — 전원·꺼짐 예약·화면 보호기·사진 (2026-11-03).
///
/// 기획 `docs/superpowers/specs/2026-11-03-lcd-screen-settings-design.md`
/// (§12 > §11 > 본문), 계약 `docs/references/2026-11-03-lcd-saver-app-guide.md`.
/// 순수 Dart — Flutter·문구 의존 없음(오전/오후 같은 글자는 화면이 붙인다).

// ── 화면 보호기 ────────────────────────────────────────────────────────────────

/// 화면 보호기 모드. 서버 `"rotate"`(사진 ↔ 온습도 교대) / `"image"`(사진만).
enum LcdSaverMode {
  rotate,
  image;

  String toWire() => this == LcdSaverMode.image ? 'image' : 'rotate';

  /// 모르는 값·null은 [rotate](서버 기본).
  static LcdSaverMode fromWire(Object? raw) =>
      raw == 'image' ? LcdSaverMode.image : LcdSaverMode.rotate;
}

/// 보호기 시간 조절 칸(stepper). 범위 끝에선 더 가지 않는다(순환 없음).
///
/// 서버 값이 칸에 맞지 않으면(웹에서 20초 등) **그대로 둔다** — 처음 누를 때
/// 가장 가까운 칸으로 맞춘다(기획 §11-4·C5).
class LcdStepper {
  const LcdStepper({required this.min, required this.max, required this.step})
      : assert(step > 0 && max >= min && (max - min) % step == 0);

  final int min;
  final int max;
  final int step;

  /// 칸에 맞는 값인가(범위 안 + 단위 배수).
  bool fits(int value) =>
      value >= min && value <= max && (value - min) % step == 0;

  /// 칸 밖 값을 가장 가까운 칸으로. 두 칸과 같은 거리면 누른 방향 쪽.
  /// [direction]은 +1(늘림) / −1(줄임).
  int snap(int value, int direction) {
    if (value <= min) return min;
    if (value >= max) return max;
    final below = min + ((value - min) ~/ step) * step;
    if (below == value) return value;
    final above = below + step;
    final dBelow = value - below;
    final dAbove = above - value;
    if (dBelow < dAbove) return below;
    if (dAbove < dBelow) return above;
    return direction > 0 ? above : below;
  }

  /// +/−를 한 번 눌렀을 때의 값. 칸 밖이면 맞추기만 하고, 끝이면 그대로.
  int next(int value, int direction) {
    if (!fits(value)) return snap(value, direction);
    final moved = value + (direction > 0 ? step : -step);
    if (moved < min || moved > max) return value;
    return moved;
  }

  /// 이 방향 버튼을 누를 수 있나 — 끝값에서 흐리게 그릴 때 쓴다.
  bool canStep(int value, int direction) => next(value, direction) != value;
}

/// 사진 노출 시간 — 1~5분(60~300초) 1분 단위(Figma 메모).
const kLcdImageSecStepper = LcdStepper(min: 60, max: 300, step: 60);

/// 온습도 표시 시간 — 10~30초 5초 단위(Figma 메모).
const kLcdInfoSecStepper = LcdStepper(min: 10, max: 30, step: 5);

/// 화면 보호기 설정(`devices.lcd_saver` JSONB / `PUT …/lcd/saver` 본문).
///
/// PUT은 부분 수정이 아니다 — 빠진 필드는 서버 기본값으로 **덮인다**
/// (가이드 §3-3). 그래서 [toJson]은 5개 필드를 항상 전부 낸다.
class LcdSaverSettings {
  const LcdSaverSettings({
    required this.enabled,
    required this.mode,
    required this.imageSec,
    required this.infoSec,
    required this.showOfflineIcon,
  });

  /// 미설정 기본값 — **Figma 기준**(사진 1분/온습도 10초, 기획 C5·§11-4).
  /// 가이드의 서버 기본 20초가 아니다. 보호기는 꺼짐, 오프라인 아이콘은 켬(D7).
  static const defaults = LcdSaverSettings(
    enabled: false,
    mode: LcdSaverMode.rotate,
    imageSec: 60,
    infoSec: 10,
    showOfflineIcon: true,
  );

  final bool enabled;
  final LcdSaverMode mode;

  /// 사진 유지 초. 서버 허용 5~300 — 칸(60초 단위)에 안 맞아도 그대로 둔다.
  final int imageSec;

  /// 온습도 유지 초. 서버 허용 3~300 — 칸(5초 단위)에 안 맞아도 그대로 둔다.
  final int infoSec;
  final bool showOfflineIcon;

  /// 서버 값 → 설정. null(한 번도 설정 안 함)·모양이 다르면 [defaults],
  /// 필드별로 빠졌거나 타입이 다르면 그 필드만 기본값.
  factory LcdSaverSettings.fromJson(Object? raw) =>
      tryParse(raw) ?? LcdSaverSettings.defaults;

  /// null이면 null(미설정을 구분할 때). 문자열 JSON도 받는다(Realtime 대비).
  static LcdSaverSettings? tryParse(Object? raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    const d = LcdSaverSettings.defaults;
    final enabled = map['enabled'];
    final offline = map['show_offline_icon'];
    return LcdSaverSettings(
      enabled: enabled is bool ? enabled : d.enabled,
      mode: LcdSaverMode.fromWire(map['mode']),
      imageSec: _positiveInt(map['image_sec']) ?? d.imageSec,
      infoSec: _positiveInt(map['info_sec']) ?? d.infoSec,
      showOfflineIcon: offline is bool ? offline : d.showOfflineIcon,
    );
  }

  /// PUT 본문 — 5개 필드 전부.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode.toWire(),
        'image_sec': imageSec,
        'info_sec': infoSec,
        'show_offline_icon': showOfflineIcon,
      };

  LcdSaverSettings copyWith({
    bool? enabled,
    LcdSaverMode? mode,
    int? imageSec,
    int? infoSec,
    bool? showOfflineIcon,
  }) =>
      LcdSaverSettings(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        imageSec: imageSec ?? this.imageSec,
        infoSec: infoSec ?? this.infoSec,
        showOfflineIcon: showOfflineIcon ?? this.showOfflineIcon,
      );

  @override
  bool operator ==(Object other) =>
      other is LcdSaverSettings &&
      other.enabled == enabled &&
      other.mode == mode &&
      other.imageSec == imageSec &&
      other.infoSec == infoSec &&
      other.showOfflineIcon == showOfflineIcon;

  @override
  int get hashCode =>
      Object.hash(enabled, mode, imageSec, infoSec, showOfflineIcon);

  @override
  String toString() => 'LcdSaverSettings(${toJson()})';
}

// ── 꺼짐 예약 (KST 벽시계) ─────────────────────────────────────────────────────

/// KST = UTC+9 고정(서머타임 없음). 폰 시간대와 무관하게 UTC로 계산한다
/// (`highlight_night_policy.dart`와 같은 방식).
const kKstOffset = Duration(hours: 9);

const _minutesPerDay = 24 * 60;

/// [instant](UTC든 로컬이든 같은 순간)의 KST 벽시계 분(0~1439).
int kstMinuteOfDay(DateTime instant) {
  final kst = instant.toUtc().add(kKstOffset);
  return kst.hour * 60 + kst.minute;
}

/// 오전/오후 + 시(1~12) + 분 — 꺼짐 시간 화면의 칸 하나.
///
/// 오전 12시 = 0시, 오후 12시 = 12시. 글자("오전"/"오후")는 화면이 붙인다.
class LcdAmPmTime {
  const LcdAmPmTime(
      {required this.pm, required this.hour12, required this.minute})
      : assert(hour12 >= 1 && hour12 <= 12),
        assert(minute >= 0 && minute < 60);

  factory LcdAmPmTime.fromMinuteOfDay(int minuteOfDay) {
    final m = minuteOfDay % _minutesPerDay;
    final h24 = m ~/ 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return LcdAmPmTime(pm: h24 >= 12, hour12: h12, minute: m % 60);
  }

  final bool pm;
  final int hour12;
  final int minute;

  int get hour24 => (hour12 % 12) + (pm ? 12 : 0);
  int get minuteOfDay => hour24 * 60 + minute;

  /// `h:mm`(시 앞 0 없음) — 화면은 앞에 오전/오후를 붙인다.
  String get clockLabel => '$hour12:${_two(minute)}';

  /// 오전/오후는 독립 토글이다.
  LcdAmPmTime withPm(bool value) =>
      LcdAmPmTime(pm: value, hour12: hour12, minute: minute);

  /// 시 화살표 — 1~12 순환, **오전/오후는 바꾸지 않는다**(Figma 메모).
  LcdAmPmTime stepHour(int direction) {
    final h = ((hour12 - 1 + (direction > 0 ? 1 : -1)) % 12 + 12) % 12 + 1;
    return LcdAmPmTime(pm: pm, hour12: h, minute: minute);
  }

  /// 분 화살표 — 10분 단위 00~50 순환, 시는 안 바뀐다(D3). 10분 단위가
  /// 아니면(웹에서 07분 등) 처음 누를 때 가까운 10분으로 맞추기만 한다.
  LcdAmPmTime stepMinute(int direction) => LcdAmPmTime(
      pm: pm, hour12: hour12, minute: stepQuietMinute(minute, direction));

  @override
  bool operator ==(Object other) =>
      other is LcdAmPmTime &&
      other.pm == pm &&
      other.hour12 == hour12 &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(pm, hour12, minute);
}

/// 꺼짐 시간 분 칸 단위(D3).
const kLcdQuietMinuteStep = 10;

/// 분 화살표 한 번(10분 단위 00~50 순환). 칸 밖 분은 같은 시 안에서 가장
/// 가까운 10분(00~50)으로 맞춘다 — 같은 거리면 누른 방향 쪽(예 05: +→10, −→00).
/// 57은 50이다(00으로 넘기면 한 시간 가까이 앞당겨진다).
int stepQuietMinute(int minute, int direction) {
  const step = kLcdQuietMinuteStep;
  const last = 60 - step; // 50
  final m = minute.clamp(0, 59);
  if (m % step != 0) {
    final below = (m ~/ step) * step;
    if (below >= last) return last;
    final above = below + step;
    final dBelow = m - below;
    final dAbove = above - m;
    if (dBelow < dAbove) return below;
    if (dAbove < dBelow) return above;
    return direction > 0 ? above : below;
  }
  final moved = m + (direction > 0 ? step : -step);
  return (moved % 60 + 60) % 60;
}

/// 화면 꺼짐 예약 시간대 — KST 벽시계 분(0~1439).
///
/// `start > end`면 자정을 넘는 구간(23:00~07:00). `start == end`는 서버가
/// 400을 돌려주므로 [isValid]가 false — 완료 버튼을 막는 데 쓴다.
class LcdQuietWindow {
  const LcdQuietWindow({required this.startMinute, required this.endMinute})
      : assert(startMinute >= 0 && startMinute < _minutesPerDay),
        assert(endMinute >= 0 && endMinute < _minutesPerDay);

  /// 처음 값 — 오후 8시~오전 8시(Figma 메모).
  static const defaults =
      LcdQuietWindow(startMinute: 20 * 60, endMinute: 8 * 60);

  final int startMinute;
  final int endMinute;

  bool get isValid => startMinute != endMinute;

  /// 서버 TIME(`23:00:00`)·`23:00` → 분. 형식이 다르거나 범위 밖이면 null.
  static int? parseMinute(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*$')
        .firstMatch(raw);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final sec = m.group(3) == null ? 0 : int.parse(m.group(3)!);
    if (h > 23 || min > 59 || sec > 59) return null;
    return h * 60 + min;
  }

  /// 시작·종료 문자열 → 구간. 둘 중 하나라도 못 읽으면 null.
  /// 같은 시각이면 구간은 만들되 [isValid]가 false다.
  static LcdQuietWindow? parse(Object? start, Object? end) {
    final s = parseMinute(start);
    final e = parseMinute(end);
    if (s == null || e == null) return null;
    return LcdQuietWindow(startMinute: s, endMinute: e);
  }

  factory LcdQuietWindow.fromAmPm(LcdAmPmTime start, LcdAmPmTime end) =>
      LcdQuietWindow(
          startMinute: start.minuteOfDay, endMinute: end.minuteOfDay);

  LcdAmPmTime get startAmPm => LcdAmPmTime.fromMinuteOfDay(startMinute);
  LcdAmPmTime get endAmPm => LcdAmPmTime.fromMinuteOfDay(endMinute);

  /// PUT 본문 `{start, end}` — KST `HH:MM` 24시간.
  Map<String, String> toApi() => {
        'start': formatApiMinute(startMinute),
        'end': formatApiMinute(endMinute)
      };

  static String formatApiMinute(int minute) =>
      '${_two(minute ~/ 60)}:${_two(minute % 60)}';

  /// 설정 화면 줄 표기 — 24시간 `H:mm~H:mm`, 시 앞 0 없음(`20:00~8:00`, D10).
  String get displayLabel =>
      '${_displayMinute(startMinute)}~${_displayMinute(endMinute)}';

  static String _displayMinute(int minute) =>
      '${minute ~/ 60}:${_two(minute % 60)}';

  /// KST 벽시계 분이 구간 안인가. 시작 포함·종료 제외, 자정 넘김 처리.
  bool containsMinute(int kstMinute) {
    if (!isValid) return false;
    final m = kstMinute % _minutesPerDay;
    if (startMinute < endMinute) return m >= startMinute && m < endMinute;
    return m >= startMinute || m < endMinute;
  }

  /// [now](어느 시간대의 DateTime이든 같은 순간)가 KST로 구간 안인가.
  bool contains(DateTime now) => containsMinute(kstMinuteOfDay(now));

  @override
  bool operator ==(Object other) =>
      other is LcdQuietWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);

  @override
  String toString() => 'LcdQuietWindow($displayLabel)';
}

// ── 기기 행의 LCD 상태 ─────────────────────────────────────────────────────────

/// `devices` 행(또는 `GET /devices/{id}/lcd`)의 화면 설정 — 서버가 기기 ACK로
/// 확정한 값. 같은 행이 3초마다 와도 하위가 흔들리지 않게 `==`가 있다(§11-1).
class DeviceLcdScreen {
  const DeviceLcdScreen({
    this.power = true,
    this.quiet,
    this.saver,
    this.imageKey,
    this.imageSetAt,
    this.updatedAt,
    this.screenOn,
    this.overrideUntil,
  });

  /// 아직 아무것도 모른다(구 서버·목록에 없음).
  static const unknown = DeviceLcdScreen();

  /// `lcd_power` — null이면 true(운영 12대 전부 true 기본, 기획 §5).
  final bool power;

  /// 꺼짐 예약. `lcd_quiet_start/end` 둘 다 있고 읽히며 시작≠종료일 때만.
  final LcdQuietWindow? quiet;

  /// `lcd_saver` — null이면 한 번도 설정 안 함([saverOrDefault]로 그린다).
  final LcdSaverSettings? saver;

  /// `lcd_image_key` — null이면 사진 없음.
  final String? imageKey;
  final DateTime? imageSetAt;
  final DateTime? updatedAt;

  /// `lcd_screen_on` — 신 펌웨어(`lcd_override`)가 보고한 **실제 화면 상태**.
  /// null이면 첫 보고 전·구 펌웨어(§12-1).
  final bool? screenOn;

  /// `lcd_override_until` — 수동 조작이 예약으로 돌아가는 시각. 타입 미확정이라
  /// ISO 시각 문자열만 관대하게 읽는다(§12-5).
  final DateTime? overrideUntil;

  LcdSaverSettings get saverOrDefault => saver ?? LcdSaverSettings.defaults;
  bool get hasImage => imageKey != null;

  factory DeviceLcdScreen.fromJson(Map<String, dynamic> j) {
    final power = j['lcd_power'];
    final quiet =
        LcdQuietWindow.parse(j['lcd_quiet_start'], j['lcd_quiet_end']);
    final key = j['lcd_image_key'];
    return DeviceLcdScreen(
      power: power is bool ? power : true,
      quiet: quiet != null && quiet.isValid ? quiet : null,
      saver: LcdSaverSettings.tryParse(j['lcd_saver']),
      imageKey: key is String && key.isNotEmpty ? key : null,
      imageSetAt: _parseTime(j['lcd_image_set_at']),
      updatedAt: _parseTime(j['lcd_updated_at']),
      screenOn: _parseLenientBool(j['lcd_screen_on']),
      overrideUntil: _parseTime(j['lcd_override_until']),
    );
  }

  /// 전원 스위치에 그릴 값(§12-1). 신 펌웨어이고 화면 상태 보고가 있으면 그
  /// 값, 아니면 `lcd_power`(구 규칙).
  bool switchOn({required bool lcdOverride}) =>
      lcdOverride && screenOn != null ? screenOn! : power;

  /// 꺼짐 예약 시간 안인가(KST). 예약이 없으면 false.
  bool inQuietAt(DateTime now) => quiet?.contains(now) ?? false;

  @override
  bool operator ==(Object other) =>
      other is DeviceLcdScreen &&
      other.power == power &&
      other.quiet == quiet &&
      other.saver == saver &&
      other.imageKey == imageKey &&
      other.imageSetAt == imageSetAt &&
      other.updatedAt == updatedAt &&
      other.screenOn == screenOn &&
      other.overrideUntil == overrideUntil;

  @override
  int get hashCode => Object.hash(power, quiet, saver, imageKey, imageSetAt,
      updatedAt, screenOn, overrideUntil);
}

// ── 기기 구분 (§12-4) ──────────────────────────────────────────────────────────

/// 모듈 화면 설정 지원 단계(`devices.capabilities`).
enum LcdSupport {
  /// `hub == true && lcd == false` — LCD 없는 허브. 홈 줄 자체를 숨긴다.
  noLcd,

  /// `hub == true` — 허브(개발 중단). 문구 줄만, 전원·사진·예약 세 줄 숨김.
  hub,

  /// `lcd_saver == true` — 전부 사용.
  supported,

  /// 그 외(capabilities null 포함) — nano 구 펌웨어. 세 줄 흐리게 + 업데이트 안내.
  needsUpdate;

  static LcdSupport fromCapabilities(Map<String, dynamic>? caps) {
    if (caps?['hub'] == true) {
      return caps?['lcd'] == false ? LcdSupport.noLcd : LcdSupport.hub;
    }
    if (caps?['lcd_saver'] == true) return LcdSupport.supported;
    return LcdSupport.needsUpdate;
  }
}

/// 신 nano 펌웨어 — 수동 전원 조작이 다음 예약 경계까지만 우선(§12-1).
bool lcdOverrideFromCapabilities(Map<String, dynamic>? caps) =>
    caps?['lcd_override'] == true;

// ── 명령 결과 ─────────────────────────────────────────────────────────────────

/// LCD 명령(`commands` 행) 결과. 문구는 화면이 고른다(기획 §11-2·§12-2).
enum LcdCommandOutcome {
  /// 아직 결과 없음(pending/sent, 또는 acked인데 result가 아직 없음).
  pending,
  ok,

  /// `expired`·`device_offline` — 기기에 안 갔다.
  notDelivered,

  /// `no_ack`·`lost` — 서버가 기기 응답을 못 받았다.
  noAck,

  /// `unknown_action` — 구 펌웨어.
  needsUpdate,

  /// 사진 다운로드·저장 실패(`dl_connect`·`dl_read`·`http_NNN`·`sha_mismatch`·
  /// `flash_write`) — 기기가 옛 사진을 먼저 지웠으므로 **사진 없음**으로 본다.
  photoLost,

  /// `busy` — 다른 사진을 받는 중. 옛 사진은 그대로.
  photoBusy,

  /// `no_token` — 기기 재페어링 필요.
  needsRepair,

  /// `bad_request`.
  badRequest,

  /// 그 외 실패.
  failed;

  bool get isPending => this == LcdCommandOutcome.pending;
  bool get isFinal => this != LcdCommandOutcome.pending;
}

/// `commands.status`·`result` 원문 → [LcdCommandOutcome].
///
/// 원문 기준이다 — `CommandResultWire`는 `dl_*`·`http_401`·`no_token`을
/// unknown으로 뭉갠다. 결과 앞의 `rejected_`(카메라 어휘)는 떼고 본다.
LcdCommandOutcome classifyLcdCommand(String? status, String? result) {
  final r = result == null
      ? null
      : (result.startsWith('rejected_') ? result.substring(9) : result);
  switch (status) {
    case null || 'pending' || 'sent':
      return LcdCommandOutcome.pending;
    case 'no_ack' || 'lost':
      return LcdCommandOutcome.noAck;
    case 'expired':
      return LcdCommandOutcome.notDelivered;
    case 'skipped':
      return r == 'device_offline'
          ? LcdCommandOutcome.notDelivered
          : LcdCommandOutcome.failed;
  }
  // acked·rejected·처음 보는 상태 — 결과로 판단한다.
  if (r == null) {
    // acked인데 result가 아직 없다 → 기다린다. rejected는 이미 끝난 것.
    return status == 'rejected'
        ? LcdCommandOutcome.failed
        : LcdCommandOutcome.pending;
  }
  if (r == 'ok') {
    return status == 'acked' ? LcdCommandOutcome.ok : LcdCommandOutcome.failed;
  }
  return lcdOutcomeOfResult(r);
}

/// 실패 결과 문자열만으로 분류(`ok` 제외).
LcdCommandOutcome lcdOutcomeOfResult(String result) {
  if (result.startsWith('http_')) return LcdCommandOutcome.photoLost;
  return switch (result) {
    'expired' ||
    'ttl_expired' ||
    'device_offline' =>
      LcdCommandOutcome.notDelivered,
    'no_ack' => LcdCommandOutcome.noAck,
    'unknown_action' => LcdCommandOutcome.needsUpdate,
    'dl_connect' ||
    'dl_read' ||
    'sha_mismatch' ||
    'flash_write' =>
      LcdCommandOutcome.photoLost,
    'busy' => LcdCommandOutcome.photoBusy,
    'no_token' => LcdCommandOutcome.needsRepair,
    'bad_request' => LcdCommandOutcome.badRequest,
    _ => LcdCommandOutcome.failed,
  };
}

// ── 공용 파서 ─────────────────────────────────────────────────────────────────

String _two(int v) => v.toString().padLeft(2, '0');

Map<String, dynamic>? _asMap(Object? raw) {
  if (raw is Map) return raw.cast<String, dynamic>();
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FormatException {
      return null;
    }
  }
  return null;
}

int? _positiveInt(Object? raw) {
  final v = switch (raw) {
    int() => raw,
    double() when raw.isFinite && raw == raw.roundToDouble() => raw.toInt(),
    String() => int.tryParse(raw.trim()),
    _ => null,
  };
  return v != null && v > 0 ? v : null;
}

DateTime? _parseTime(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}

bool? _parseLenientBool(Object? raw) => switch (raw) {
      bool() => raw,
      'true' || 't' || '1' => true,
      'false' || 'f' || '0' => false,
      1 => true,
      0 => false,
      _ => null,
    };
