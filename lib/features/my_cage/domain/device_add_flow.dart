import 'pair_target_kind.dart';
import 'wifi_access_point.dart';

enum DeviceAddStep { scan, networks, credentials, connecting, results }

enum DeviceAddOutcome { registered, registrationPending, wifiFailed, failed }

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
      this.wifiConnected = false});
  final DeviceAddCandidate candidate;
  final DeviceAddOutcome outcome;
  final String? registeredId;
  final String? hardwareId;
  final bool wifiConnected;
  bool get canRetry =>
      outcome == DeviceAddOutcome.failed ||
      outcome == DeviceAddOutcome.wifiFailed;
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
      {required this.wifiConnected, this.hardwareId, this.retrySafe = false});
  final bool wifiConnected;
  final String? hardwareId;

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
      required bool Function() isCurrent});
  Future<void> dispose();
}

typedef DeviceAddAutoGroup = Future<String> Function(
    String accountId, Map<PairTargetKind, String> registeredIds);
