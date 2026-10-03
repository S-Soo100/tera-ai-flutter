/// 기기 재시작·Wi-Fi 약함 안내 — 카메라(2026-09-28, petcam 요청서
/// `docs/references/2026-09-28-camera-reboot-rssi-request*.md`)와 사육장
/// (같은 날 `…device-reboot-rssi-request.md`)이 같은 규칙을 쓴다.
///
/// | | 카메라 | 사육장 |
/// |---|---|---|
/// | 값 | `cameras.clip_stats.sys` | `devices.sys_state` |
/// | 보고 기준 | `clip_stats_at`(약 15초) | `last_seen_at`(약 3초) |
/// | 신 펌웨어 | `firmware_ver` ≥ 0.2.0 | `sys_state != null` |
/// | 약함 연속 | 4번 | 20번(둘 다 약 1분) |
///
/// 키가 없으면 전부 "없음" — 구 펌웨어에선 아무것도 보이지 않는다.
library;

import 'pair_target_kind.dart';
import 'terra_camera.dart';

/// 재시작·Wi-Fi 약함 대상 — (종류, 행 id). provider family 키로 쓴다.
typedef SysTarget = (PairTargetKind, String);

/// 카메라가 재시작 명령을 아는 펌웨어(0.2.0 이상)인가(2026-09-28 형식 확정:
/// `fb2-p4 <major.minor.patch>[-<build>]`). 숫자로 비교하고, null·파싱 실패는
/// false(숨김). **사육장은 버전으로 판별하지 않는다** — `sys_state` 유무로 본다.
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

/// 이 카메라에 재시작을 보여 줄 수 있나 — 켜져 있고 0.2.0 이상 펌웨어.
/// 기기 상세 줄과 라이브 실패 화면이 같은 조건을 쓴다.
bool cameraRebootCapable(TerraCamera? camera) =>
    camera != null &&
    camera.isOnline &&
    isRebootCapableFirmware(camera.firmwareVer);

/// Wi-Fi 약함 기준 — 운영 콘솔(−75 이하 빨강)과 같게 **−75 이하 = 약함**.
const kWeakRssi = -75;

/// 약함이 이만큼 연속(서로 다른 보고)이면 안내한다 — 둘 다 약 1분.
const kWeakRssiStreakCamera = 4;
const kWeakRssiStreakDevice = 20;

/// 재시작 완료 신호가 이만큼 안 오면 전원 재연결을 안내한다.
const kRebootTimeout = Duration(minutes: 2);

/// 재시작 완료 신호가 이만큼 안 오면 "확인이 늦어지고 있어요"로 바꾼다
/// (가이드 2026-10-03 §2의 60초 — 끝내지 않고 [kRebootTimeout]까지 기다린다).
const kRebootSlowAfter = Duration(seconds: 60);

/// 재시작 명령이 나간 뒤 버튼을 다시 누를 수 없는 시간.
const kRebootCooldown = Duration(seconds: 60);

/// MQTT 재시작 명령으로 재부팅했을 때의 리셋 사유(2026-09-28 백엔드 확정,
/// 카메라 실측: 버튼→재부팅 1.5초, 재부팅→첫 heartbeat 최대 27초).
const kMqttRebootReason = 'SW:mqtt_reboot';

/// 카메라 재시작 응답의 `published`를 믿어도 되는가. 2026-10-03 서버가 발행에
/// 성공해도 `{"published": false}`를 돌려주던 버그(gwanhun/terra-server#17) 동안
/// false로 두었다가, 같은 날 운영 배포 뒤 true로 되돌렸다 — 이제 `false`는 실제
/// 브로커 장애다(잠시 뒤 다시). 경위 `docs/handoffs/2026-10-03-camera-reboot-published-false.md`.
const kCameraRebootPublishedReliable = true;

/// 카메라 재시작 응답(200 본문)이 "발행됨"인가. 401·404·5xx는 이전 단계에서
/// 예외로 갈린다 — 여기 오면 200이다.
bool cameraRebootAccepted(Object? body,
    {bool publishedReliable = kCameraRebootPublishedReliable}) {
  if (!publishedReliable) return true;
  return body is Map && body['published'] == true;
}

/// 사육장 재시작 확인창의 임시 문장("예약으로 켜져 있던 조명·팬은 다음 예약
/// 시각까지 꺼져 있을 수 있어요") — 서버가 재부팅 뒤 예약 상태를 되살리는 기능을
/// 배포하면 false로 바꾼다(요청서 §2-2).
const kDeviceRebootScheduleNote = true;

/// 기기 heartbeat의 앱이 쓰는 값만 — 진단 필드(`heap`·`last_err`·`up_fail` 등)는
/// 앱에 보이지 않는다(운영 콘솔 전용). `reset`·`uptime_s`도 판정에만 쓴다.
class SysHealth {
  const SysHealth(
      {this.present = false,
      this.uptimeSeconds,
      this.resetReason,
      this.rssi,
      this.statsAt,
      this.isOnline});

  /// 기기가 이 값을 보고하는가 — 사육장은 이것이 신 펌웨어 판별이다.
  final bool present;
  final int? uptimeSeconds;
  final String? resetReason;
  final int? rssi;

  /// 서로 다른 보고를 가르는 기준(카메라 `clip_stats_at`, 사육장 `last_seen_at`).
  final DateTime? statsAt;

  /// 사육장 행의 `is_online`(같은 UPDATE로 온다). 카메라는 목록 provider를 본다.
  final bool? isOnline;

  static const empty = SysHealth();

  /// `cameras` 행 — `clip_stats.sys`.
  factory SysHealth.fromCameraRow(Map<String, dynamic> row) => _parse(
      row['clip_stats'] is Map ? (row['clip_stats'] as Map)['sys'] : null,
      row['clip_stats_at'],
      null);

  /// `devices` 행 — `sys_state`.
  factory SysHealth.fromDeviceRow(Map<String, dynamic> row) => _parse(
      row['sys_state'],
      row['last_seen_at'],
      row['is_online'] is bool ? row['is_online'] as bool : null);

  static SysHealth _parse(Object? sys, Object? at, bool? online) {
    int? integer(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    final map = sys is Map ? sys : null;
    return SysHealth(
        present: map != null,
        uptimeSeconds: integer(map?['uptime_s']),
        resetReason:
            map?['reset'] is String ? map!['reset'] as String : null,
        rssi: integer(map?['rssi']),
        statsAt: at == null ? null : DateTime.tryParse(at.toString()),
        isOnline: online);
  }

  /// 재시작 명령 뒤 이 값이 "재시작 완료"인가 — 리셋 사유가 MQTT 재시작이고,
  /// 다음 중 하나로 **누른 뒤에 켜졌음**이 확인될 때. 리셋 사유만으로는 보지
  /// 않는다(직전에도 원격 재시작을 했으면 이미 같은 값이다).
  ///
  /// - 가동 시간이 누르기 직전([uptimeBefore])보다 줄었다.
  /// - 가동 시간이 누른 뒤 흐른 시간([sincePress], 폰 단조 시계) 이하다 —
  ///   누르기 전 가동 시간을 못 읽었을 때(라이브 실패 화면에서 바로 누름)의
  ///   기준(2026-10-03). 서버 시각(`clip_stats_at`)과 비교하지 않아 폰 시계가
  ///   어긋나도 맞다. 보고가 늦게 도착할수록 여유가 커지는 쪽이라 안전하다.
  bool rebootedSince(int? uptimeBefore, {Duration? sincePress}) {
    final now = uptimeSeconds;
    if (now == null || resetReason != kMqttRebootReason) return false;
    if (uptimeBefore != null && now < uptimeBefore) return true;
    return sincePress != null &&
        now <= sincePress.inSeconds + kRebootUptimeSlackSeconds;
  }
}

/// [SysHealth.rebootedSince]의 가동 시간 반올림 여유(초).
const kRebootUptimeSlackSeconds = 2;

/// Wi-Fi 약함 연속 횟수 — 상세를 보는 동안만 센다(화면을 나가면 버린다).
/// 같은 보고(`statsAt`)의 중복 UPDATE는 한 번만, −74 이상이 한 번이라도 오면 0.
/// 값 자체가 없는 보고(구 펌웨어)는 무시한다. 값은 있는데 `rssi`만 빠진 보고는
/// 카메라는 무시하고, 사육장은 0으로 되돌린다([resetOnMissingRssi], 요청서 §3).
class WeakSignalStreak {
  WeakSignalStreak({required this.threshold, this.resetOnMissingRssi = false});

  factory WeakSignalStreak.forKind(PairTargetKind kind) =>
      kind == PairTargetKind.camera
          ? WeakSignalStreak(threshold: kWeakRssiStreakCamera)
          : WeakSignalStreak(
              threshold: kWeakRssiStreakDevice, resetOnMissingRssi: true);

  final int threshold;
  final bool resetOnMissingRssi;
  int _count = 0;
  DateTime? _lastAt;

  int get count => _count;

  /// 이번 값까지 반영해 안내할 때가 됐으면 true.
  bool add(SysHealth health) {
    final at = health.statsAt;
    if (!health.present || at == null) return false;
    if (_lastAt != null && !at.isAfter(_lastAt!)) return false;
    _lastAt = at;
    final rssi = health.rssi;
    if (rssi == null) {
      if (resetOnMissingRssi) _count = 0;
      return false;
    }
    _count = rssi <= kWeakRssi ? _count + 1 : 0;
    return _count >= threshold;
  }
}
