import 'pair_target_kind.dart';
import 'wifi_access_point.dart';

enum DeviceAddStep { scan, networks, credentials, connecting, results }

/// [wifiUpdated]: 이미 등록된 카메라의 Wi-Fi만 바꿨다 — 새 등록 없이 기존
/// id를 그대로 쓴다(2026-09-21, 재페어링마다 새 camera_id로 중복 등록되던 문제).
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
      this.hardwareId,
      this.wifiConnected = false,
      this.reconnect,
      this.issue,
      this.issueDetail});
  final DeviceAddCandidate candidate;
  final DeviceAddOutcome outcome;
  final String? registeredId;
  final String? hardwareId;
  final bool wifiConnected;
  final CameraReconnect? reconnect;
  final DeviceRegistrationIssue? issue;
  final String? issueDetail;
  DeviceAddResult withReconnect(CameraReconnect value) => DeviceAddResult(
      candidate: candidate,
      outcome: outcome,
      registeredId: registeredId,
      hardwareId: hardwareId,
      wifiConnected: wifiConnected,
      reconnect: value,
      issue: issue,
      issueDetail: issueDetail);

  /// 사육장은 등록 대기여도 다시 보낼 수 있다 — `UNPAIR` 뒤 같은 `device_id`로
  /// 재등록돼 행이 늘지 않는다. 카메라는 JWT를 받을 때마다 새 `camera_id`로
  /// 등록하므로 등록 대기면 막는다(중복 행).
  bool get canRetry =>
      outcome == DeviceAddOutcome.failed ||
      outcome == DeviceAddOutcome.wifiFailed ||
      (outcome == DeviceAddOutcome.registrationPending &&
          candidate.kind == PairTargetKind.device);
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
      this.groupError = false});
  final DeviceAddStep step;
  final List<DeviceAddCandidate> candidates;
  final Map<PairTargetKind, DeviceAddCandidate> selected;
  final List<WifiAccessPoint> networks;
  final Map<PairTargetKind, DeviceAddResult> results;
  final bool busy, remember, showPassword, groupError;
  final String ssid;
  final String? errorKey, activePhysicalId, groupId;
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
          bool? groupError}) =>
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
          groupError: groupError ?? this.groupError);
}

class DeviceProvisionReceipt {
  const DeviceProvisionReceipt(
      {required this.wifiConnected,
      this.hardwareId,
      this.retrySafe = false,
      this.issue,
      this.issueDetail});
  final bool wifiConnected;
  final String? hardwareId;
  final DeviceRegistrationIssue? issue;
  final String? issueDetail;

  /// False after CONNECT when registration could have occurred without ACK.
  final bool retrySafe;
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
