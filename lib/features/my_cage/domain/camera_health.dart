/// 카메라 재시작·Wi-Fi 약함 안내(2026-09-28, petcam 요청서
/// `APP_REQUEST_CAMERA_REBOOT_RSSI_2026-09-28`, 백엔드 terra-server `88ab198`).
///
/// 값은 `cameras.clip_stats.sys`(펌웨어 heartbeat, 약 15초마다)에서 읽는다.
/// 구 펌웨어(`fb2-p4 0.1.0`)는 `rssi`가 없고 재시작 명령도 모른다 — 키가 없으면
/// 전부 "없음"으로 두고 아무것도 보이지 않는다.
library;

/// 재시작 명령을 아는 펌웨어(0.2.0 이상)인가. 형식은
/// `<이름> <major.minor.patch>[-<빌드>]`(예: `fb2-p4 0.2.0-20260928`). 문자열
/// 비교가 아니라 숫자로 본다. null·파싱 실패는 false(숨김) — 형식이 달라도 안전하다.
bool isRebootCapableFirmware(String? firmware) {
  if (firmware == null) return false;
  final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(firmware);
  if (m == null) return false;
  final version = [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  const min = [0, 2, 0];
  for (var i = 0; i < 3; i++) {
    if (version[i] != min[i]) return version[i] > min[i];
  }
  return true;
}

/// Wi-Fi 약함 기준 — 운영 콘솔(−75 이하 빨강)과 같게 **−75 이하 = 약함**.
const kWeakRssi = -75;

/// 약함이 이만큼 연속(서로 다른 heartbeat)이면 안내한다 — 약 1분.
const kWeakRssiStreak = 4;

/// 재시작 완료 신호가 이만큼 안 오면 전원 재연결을 안내한다.
const kRebootTimeout = Duration(minutes: 2);

/// 재시작 명령이 나간 뒤 버튼을 다시 누를 수 없는 시간.
const kRebootCooldown = Duration(seconds: 60);

/// 펌웨어가 MQTT 재시작 명령으로 재부팅했을 때 보고하는 리셋 사유.
/// 백엔드 표기 확인 중 — 다르면 완료 판정 대신 2분 뒤 안내가 뜬다(안전).
const kMqttRebootReason = 'SW:mqtt_reboot';

/// `cameras.clip_stats.sys`의 앱이 쓰는 값만 — 진단 필드(`last_err`·`up_fail`
/// 등)는 앱에 보이지 않는다(요청서 §4, 운영 콘솔 전용).
class CameraHealth {
  const CameraHealth(
      {this.uptimeSeconds, this.resetReason, this.rssi, this.statsAt});

  final int? uptimeSeconds;
  final String? resetReason;
  final int? rssi;

  /// `clip_stats_at` — 서로 다른 heartbeat를 가르는 기준.
  final DateTime? statsAt;

  static const empty = CameraHealth();

  /// `cameras` 행(직결 조회·Realtime newRecord). 키가 없거나 모양이 달라도
  /// 던지지 않고 null로 둔다.
  factory CameraHealth.fromRow(Map<String, dynamic> row) {
    final stats = row['clip_stats'];
    final sys = stats is Map ? stats['sys'] : null;
    int? integer(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    final at = row['clip_stats_at'];
    return CameraHealth(
        uptimeSeconds: sys is Map ? integer(sys['uptime_s']) : null,
        resetReason: sys is Map && sys['reset'] is String
            ? sys['reset'] as String
            : null,
        rssi: sys is Map ? integer(sys['rssi']) : null,
        statsAt: at == null ? null : DateTime.tryParse(at.toString()));
  }

  /// 재시작 명령 뒤 이 값이 "재시작 완료"인가 — 가동 시간이 명령 전보다
  /// 줄었고 리셋 사유가 MQTT 재시작이다. 명령 전 가동 시간을 몰랐으면 판정할
  /// 수 없다(2분 뒤 안내로 떨어진다).
  bool rebootedSince(int? uptimeBefore) {
    final now = uptimeSeconds;
    return uptimeBefore != null &&
        now != null &&
        now < uptimeBefore &&
        resetReason == kMqttRebootReason;
  }
}

/// Wi-Fi 약함 연속 횟수 — 카메라 상세를 보는 동안만 센다(화면을 나가면 버린다).
/// 같은 heartbeat(`clip_stats_at`)의 중복 UPDATE는 한 번만, −74 이상이 한 번이라도
/// 오면 0으로, `rssi`가 없으면(구 펌웨어) 아무것도 하지 않는다.
class WeakSignalStreak {
  int _count = 0;
  DateTime? _lastAt;

  int get count => _count;

  /// 이번 값까지 반영해 안내할 때가 됐으면 true.
  bool add(CameraHealth health) {
    final rssi = health.rssi;
    final at = health.statsAt;
    if (rssi == null || at == null) return false;
    if (_lastAt != null && !at.isAfter(_lastAt!)) return false;
    _lastAt = at;
    _count = rssi <= kWeakRssi ? _count + 1 : 0;
    return _count >= kWeakRssiStreak;
  }
}
