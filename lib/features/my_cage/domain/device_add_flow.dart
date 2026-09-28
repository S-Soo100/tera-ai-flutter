import 'pair_target_kind.dart';
import 'wifi_access_point.dart';

enum DeviceAddStep { scan, networks, credentials, connecting, results }

/// 사육장도 등록을 지우지 않고 Wi-Fi만 바꾼다(2026-09-28). 펌웨어는 저장된
/// 서버 자격증명이 있으면 `CONNECT` 때 pair를 건너뛴다(terra-server
/// FIRMWARE_INTEGRATION §2) — 앱이 `UNPAIR`·`NAME`·`JWT`를 빼면 같은
/// `device_id`로 다시 붙는다. **실기기에서 같은 행으로 안 붙으면 false로
/// 바꾼다**(사용자 결정: 사육장만 숨기고 카메라는 유지). false면 사육장은 예전처럼
/// 늘 새로 등록하고, 등록된 사육장을 고르면 '새 기기로 등록' 경고를 띄운다.
const kWifiChangeDeviceEnabled = true;

/// 이 종류의 기기가 등록을 유지한 채 Wi-Fi만 바꿀 수 있는가.
bool supportsWifiChange(PairTargetKind kind) =>
    kind == PairTargetKind.camera || kWifiChangeDeviceEnabled;

/// 기기 상세·라이브 오프라인 안내의 [Wi-Fi 바꾸기] 대상(2026-09-28).
/// 근처 기기 중 대상을 알아보는 건 서버 `hw_id`([bleMatchesHardware])·이 폰의
/// 기억이고, 못 알아봐도 유저가 목록에서 고를 수 있다. 최종 판정은 대상 행의
/// `last_seen_at`이다.
class WifiChangeTarget {
  const WifiChangeTarget(
      {required this.kind, required this.id, required this.name});
  final PairTargetKind kind;

  /// `devices.id`/`cameras.id`(행 UUID).
  final String id;
  final String name;
}

/// 서버에 남아 있는 이 계정의 기기 행 — 해제·타 계정이면 조회 결과가 null이다.
/// [isOnline]은 Wi-Fi 변경 판정에 쓴다: 대상이 원래 Wi-Fi로 온라인이면 새
/// 하트비트가 새 Wi-Fi 접속인지 옛 접속인지 가릴 수 없다.
typedef OwnedDeviceRow = ({
  DateTime? lastSeen,
  String? hardwareId,
  bool? isOnline
});

/// BLE 기기가 서버 `hw_id`의 그 기기로 보이는가 — 힌트일 뿐이다(2026-09-28).
/// ESP32는 MAC 4개를 연속으로 쓰고 블루투스 MAC은 기준 MAC+2다. `hw_id`가
/// Wi-Fi(기준) MAC인지 블루투스 MAC인지 아직 모르므로 차이 0·2만 같은 기기로 본다
/// (연속 번호 기기끼리는 4씩 벌어져 겹치지 않는다).
/// - Android: [DeviceAddCandidate.physicalId]가 `AA:BB:CC:DD:EE:FF` MAC.
/// - iOS: 주소가 폰마다 다른 UUID라 광고 이름 끝 `_XXXX`(MAC 하위 2바이트)만 본다.
bool bleMatchesHardware(DeviceAddCandidate candidate, String? hardwareId) {
  final hw = _hex(hardwareId);
  if (hw == null || hardwareId!.length != 12) return false;
  bool near(int a, int b, int mask) {
    final d = (a - b) & mask;
    return d == 0 || d == 2;
  }

  final address = candidate.physicalId.replaceAll(':', '');
  if (address.length == 12) {
    final ble = _hex(address);
    if (ble != null) return near(ble, hw, 0xFFFFFFFFFFFF);
  }
  final suffix = RegExp(r'_([0-9A-Fa-f]{4})$').firstMatch(candidate.name);
  if (suffix != null) {
    return near(int.parse(suffix.group(1)!, radix: 16), hw & 0xFFFF, 0xFFFF);
  }
  return false;
}

int? _hex(String? value) {
  if (value == null || value.isEmpty) return null;
  if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(value)) return null;
  return int.parse(value, radix: 16);
}

/// [wifiUpdated]: 이미 등록된 기기의 Wi-Fi만 바꿨다 — 새 등록 없이 기존
/// id를 그대로 쓴다(2026-09-21 카메라, 2026-09-28 사육장 — 재페어링마다 새 행으로
/// 중복 등록되던 문제).
enum DeviceAddOutcome {
  registered,
  registrationPending,
  wifiFailed,
  failed,
  wifiUpdated
}

/// Wi-Fi만 바꾼 카메라가 재부팅 뒤 서버에 다시 붙었는지. 카메라 저장값이
/// 지워진 경우(초기화 등) 등록 없이는 영영 안 붙으므로 [missing]이면 새
/// 카메라로 등록할 길을 연다.
enum CameraReconnect { waiting, online, missing }

/// 등록 확인이 안 된 이유 — 결과 화면에 밝혀 원인을 가린다(2026-09-21, 사육장이
/// Wi-Fi만 붙고 pair를 안 한 사고에서 '등록 확인 대기' 한 줄로는 구 펌웨어와
/// 서버 등록 실패를 구분할 수 없었다).
/// [legacyFirmware]: `NAME:`에 응답 없음/`ERR:UNKNOWN_CMD` — JWT를 보내지 않았다.
/// [pairFailed]: 기기가 `PAIR_FAIL <사유>`를 보냈다(사유는 [DeviceAddResult.issueDetail]).
/// [noPairReply]: JWT·CONNECT까지 갔지만 `PAIR_OK`/`PAIR_FAIL`이 오지 않았다.
enum DeviceRegistrationIssue { legacyFirmware, pairFailed, noPairReply }

/// `CONNECT` 전에 끝난 실패의 종류(2026-09-25). 전엔 모두 Wi-Fi 실패로 묶여
/// 블루투스가 안 붙어도 "비밀번호를 다시 확인해 주세요"가 떴다.
/// [ble]: 기기를 못 찾았거나 블루투스 연결·응답이 끊겼다(멀다·광고 끝남).
/// [session]: 로그인 토큰을 못 얻었다. [rejected]: 기기가 이름·토큰을 거절했다.
enum DeviceProvisionFailure { ble, session, rejected }

class DeviceAddCandidate {
  const DeviceAddCandidate(
      {required this.physicalId,
      required this.kind,
      required this.name,
      required this.rssi});
  final String physicalId;
  final PairTargetKind kind;
  final String name;
  final int rssi;
}

class DeviceAddResult {
  const DeviceAddResult(
      {required this.candidate,
      required this.outcome,
      this.registeredId,
      this.registeredName,
      this.hardwareId,
      this.wifiConnected = false,
      this.reconnect,
      this.issue,
      this.issueDetail,
      this.failure,
      this.unverified = false});
  final DeviceAddCandidate candidate;

  /// Wi-Fi 바꾸기에서 대상 신호는 왔지만 고른 기기가 대상인지 확인할 수 없다 —
  /// 대상이 원래 Wi-Fi로 온라인이었고 목록에서 알아보지 못한 기기를 골랐다.
  /// 그 기기를 대상으로 기억하지 않는다(다음 등록이 Wi-Fi 변경으로 샌다).
  final bool unverified;

  /// [DeviceAddOutcome.failed]의 이유 — 결과 화면이 할 일을 밝힌다.
  final DeviceProvisionFailure? failure;
  final DeviceAddOutcome outcome;
  final String? registeredId;

  /// 앱이 `NAME:`으로 보낸 등록 이름("사육장 5") — 화면엔 BLE 광고 이름 대신
  /// 이것을 보인다. Wi-Fi만 바꾼 카메라처럼 이름을 안 보냈으면 null.
  final String? registeredName;
  final String? hardwareId;
  final bool wifiConnected;
  final CameraReconnect? reconnect;
  final DeviceRegistrationIssue? issue;
  final String? issueDetail;
  DeviceAddResult withReconnect(CameraReconnect value,
          {bool unverified = false}) =>
      DeviceAddResult(
          candidate: candidate,
          outcome: outcome,
          registeredId: registeredId,
          registeredName: registeredName,
          hardwareId: hardwareId,
          wifiConnected: wifiConnected,
          reconnect: value,
          issue: issue,
          issueDetail: issueDetail,
          failure: failure,
          unverified: unverified);

  /// 사육장은 등록 대기여도 다시 보낼 수 있다. ⚠️ 다시 보내면 `UNPAIR` 뒤 서버가
  /// **새 `device_id`로 새 행**을 만든다(2026-09-25 운영 확인 — 전엔 같은 행으로
  /// 잡힌다고 잘못 적혀 있었다). 늦게 등록된 앞 행은 남을 수 있다. 카메라는 JWT를
  /// 받을 때마다 새 `camera_id`로 등록하므로 등록 대기면 막는다(중복 행).
  /// Wi-Fi만 바꾼 카메라가 BLE로 성공을 알리지 않았고(끊김·무응답·WIFI_FAIL)
  /// 서버 last_seen_at으로도 끝내 안 붙었으면 실패다 — 다시 보낼 수 있다.
  bool get canRetry =>
      outcome == DeviceAddOutcome.failed ||
      outcome == DeviceAddOutcome.wifiFailed ||
      (outcome == DeviceAddOutcome.registrationPending &&
          candidate.kind == PairTargetKind.device) ||
      reconnectMissing;

  /// Wi-Fi만 바꿨는데 서버에서 그 기기 신호가 끝내 오지 않았다. `NAME`·`JWT`를
  /// 안 보냈으니 등록은 일어날 수 없어 다시 보내도 안전하다 — BLE가 WIFI_OK를
  /// 줬어도(다른 기기를 골랐거나 저장값이 지워진 경우) 다시 시도할 수 있다.
  bool get reconnectMissing =>
      outcome == DeviceAddOutcome.wifiUpdated &&
      reconnect == CameraReconnect.missing;

  /// BLE가 Wi-Fi 성공을 주지 않은 Wi-Fi 변경 — 최종 판정은 서버 last_seen_at.
  bool get unconfirmed =>
      outcome == DeviceAddOutcome.wifiUpdated && !wifiConnected;

  bool get unconfirmedFailed =>
      unconfirmed && reconnect == CameraReconnect.missing;
}

class DeviceAddState {
  const DeviceAddState(
      {this.step = DeviceAddStep.scan,
      this.candidates = const [],
      this.selected = const {},
      this.networks = const [],
      this.results = const {},
      this.busy = false,
      this.remember = false,
      this.showPassword = false,
      this.ssid = '',
      this.errorKey,
      this.activePhysicalId,
      this.groupId,
      this.groupError = false,
      this.registered = const {},
      this.matched = const {},
      this.targetGone = false});
  final DeviceAddStep step;
  final List<DeviceAddCandidate> candidates;
  final Map<PairTargetKind, DeviceAddCandidate> selected;
  final List<WifiAccessPoint> networks;
  final Map<PairTargetKind, DeviceAddResult> results;
  final bool busy, remember, showPassword, groupError;
  final String ssid;
  final String? errorKey, activePhysicalId, groupId;

  /// 이 폰이 등록해 계정에 남아 있는 기기의 BLE 주소 — 목록에 '이미 등록됨'.
  final Set<String> registered;

  /// Wi-Fi 바꾸기에서 대상 기기로 보이는 BLE 주소([bleMatchesHardware] 또는 이
  /// 폰의 기억). 힌트라서 다른 기기를 골라도 막지 않는다.
  final Set<String> matched;

  /// Wi-Fi 바꾸기 대상 행이 해제됐거나 이 계정 것이 아니다 — Wi-Fi만 붙여도
  /// 목록에 안 보이니 진행하지 않는다. (errorKey는 다음 갱신에 지워진다.)
  final bool targetGone;
  DeviceAddState copyWith(
          {DeviceAddStep? step,
          List<DeviceAddCandidate>? candidates,
          Map<PairTargetKind, DeviceAddCandidate>? selected,
          List<WifiAccessPoint>? networks,
          Map<PairTargetKind, DeviceAddResult>? results,
          bool? busy,
          bool? remember,
          bool? showPassword,
          String? ssid,
          String? errorKey,
          String? activePhysicalId,
          String? groupId,
          bool? groupError,
          Set<String>? registered,
          Set<String>? matched,
          bool? targetGone}) =>
      DeviceAddState(
          step: step ?? this.step,
          candidates: candidates ?? this.candidates,
          selected: selected ?? this.selected,
          networks: networks ?? this.networks,
          results: results ?? this.results,
          busy: busy ?? this.busy,
          remember: remember ?? this.remember,
          showPassword: showPassword ?? this.showPassword,
          ssid: ssid ?? this.ssid,
          errorKey: errorKey,
          activePhysicalId: activePhysicalId,
          groupId: groupId ?? this.groupId,
          groupError: groupError ?? this.groupError,
          registered: registered ?? this.registered,
          matched: matched ?? this.matched,
          targetGone: targetGone ?? this.targetGone);
}

class DeviceProvisionReceipt {
  const DeviceProvisionReceipt(
      {required this.wifiConnected,
      this.hardwareId,
      this.retrySafe = false,
      this.connectSent = false,
      this.wifiRejected = false,
      this.failure,
      this.issue,
      this.issueDetail});
  final bool wifiConnected;
  final String? hardwareId;

  /// `CONNECT` 전에 끝났으면 그 이유. Wi-Fi 거절([wifiRejected])과 다르다.
  final DeviceProvisionFailure? failure;
  final DeviceRegistrationIssue? issue;
  final String? issueDetail;

  /// False after CONNECT when registration could have occurred without ACK.
  final bool retrySafe;

  /// `CONNECT`가 기기에 갔다 — 기기가 새 자격증명을 시도했을 수 있다. 거짓이면
  /// (BLE 연결 실패·계정 전환 등 그 전 단계 예외) 기기는 아무것도 안 했다.
  final bool connectSent;

  /// 기기가 `WIFI_FAIL`로 실패를 확정했다(비밀번호 오류 등). BLE 끊김·무응답과
  /// 달리 추측할 여지가 없다.
  final bool wifiRejected;

  /// Wi-Fi 변경 결과를 서버 last_seen_at으로 판정할 근거가 있는가 —
  /// BLE가 성공을 확정했거나, `CONNECT`는 갔는데 회신 없이 끊긴 경우만.
  /// 기기가 실패를 확정했거나 시도조차 안 했으면 서버 감시는 오판(옛 Wi-Fi
  /// 하트비트가 계속 온다)이라 즉시 실패로 둔다.
  bool get worthWatching => wifiConnected || (connectSent && !wifiRejected);
}

abstract interface class DeviceAddGateway {
  Stream<List<DeviceAddCandidate>> get scanResults;
  Future<void> startScan();
  Future<void> stopScan();
  Future<List<WifiAccessPoint>> networks(DeviceAddCandidate candidate);
  Future<DeviceProvisionReceipt> provision(DeviceAddCandidate candidate,
      {required String ssid,
      required String password,
      required String name,
      required String jwt,
      required Future<void> Function() onWifiConnected,
      required bool Function() isCurrent,
      bool wifiOnly = false});
  Future<void> dispose();
}

typedef DeviceAddAutoGroup = Future<String> Function(
    String accountId, Map<PairTargetKind, String> registeredIds);

/// 검색을 시작하지 못한 이유 — 유저가 할 일이 다르다(2026-09-25).
enum DeviceAddScanProblem { permission, bluetoothOff }

class DeviceAddScanException implements Exception {
  const DeviceAddScanException(this.problem);
  final DeviceAddScanProblem problem;
  @override
  String toString() => 'DeviceAddScanException($problem)';
}
