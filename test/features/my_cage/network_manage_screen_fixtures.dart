// 네트워크 관리 화면(Figma 1913:6570·7778) 공용 테스트 값 — 화면 테스트와
// 글자 배율 넘침 테스트가 같이 쓴다.
import 'package:vivanaut/features/my_cage/data/device_wifi_name_store.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/network_manage.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

const nmCamera = DeviceAddCandidate(
    physicalId: 'AA:00:00:00:00:01',
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM_EE12',
    rssi: -50);
const nmDevice = DeviceAddCandidate(
    physicalId: 'AA:00:00:00:00:02',
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -45);
const nmOffline = DeviceAddCandidate(
    physicalId: 'AA:00:00:00:00:03',
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -60);
const nmBare = DeviceAddCandidate(
    physicalId: 'AA:00:00:00:00:04',
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -70);

/// 온라인·약한 신호·서버 Wi-Fi 이름 있음.
const nmCameraRow = OwnedNetworkDevice(
    kind: PairTargetKind.camera,
    id: 'c4',
    name: '카메라 4',
    hardwareId: 'p4cam-0d1b47b4',
    isOnline: true,
    wifiRssi: -78,
    wifiSsid: 'iptime');

/// 온라인·서버 이름 없음(이 폰의 기억이 있으면 그 이름).
const nmDeviceRow = OwnedNetworkDevice(
    kind: PairTargetKind.device,
    id: 'd1',
    name: '사육장 1',
    hardwareId: 'viva-iot-1234',
    isOnline: true,
    wifiRssi: -55);

/// 오프라인·`hw_id` 없음.
const nmOfflineRow = OwnedNetworkDevice(
    kind: PairTargetKind.device,
    id: 'd2',
    name: '사육장 2',
    isOnline: false,
    wifiRssi: -60,
    wifiSsid: 'old');

/// 온라인인데 신호·이름 모두 모름.
const nmBareRow = OwnedNetworkDevice(
    kind: PairTargetKind.device, id: 'd3', name: '사육장 3', isOnline: true);

const Map<String, NetworkMatch> nmOwned = {
  'AA:00:00:00:00:01': (device: nmCameraRow, via: NetworkMatchVia.hardware),
  'AA:00:00:00:00:02': (device: nmDeviceRow, via: NetworkMatchVia.memory),
  'AA:00:00:00:00:03': (device: nmOfflineRow, via: NetworkMatchVia.hardware),
  'AA:00:00:00:00:04': (device: nmBareRow, via: NetworkMatchVia.hardware),
};

DeviceAddState nmScan(
        {Map<String, DeviceAddCandidate> selected = const {},
        bool loadFailed = false}) =>
    DeviceAddState(
        networkManage: true,
        candidates: const [nmCamera, nmDevice, nmOffline, nmBare],
        owned: nmOwned,
        selected: selected,
        ownedLoadFailed: loadFailed);

DeviceAddResult nmUpdated(
        DeviceAddCandidate c, String rowId, CameraReconnect reconnect,
        {bool unverified = false}) =>
    DeviceAddResult(
        candidate: c,
        outcome: DeviceAddOutcome.wifiUpdated,
        registeredId: rowId,
        wifiConnected: true,
        reconnect: reconnect,
        unverified: unverified);

DeviceAddState nmResults(Map<String, DeviceAddResult> results) =>
    DeviceAddState(
        networkManage: true,
        step: DeviceAddStep.results,
        ssid: 'home',
        candidates: const [nmCamera, nmDevice, nmOffline, nmBare],
        owned: nmOwned,
        results: results);

/// 결과 8갈래를 한 화면에 — 배율 넘침 확인용.
DeviceAddState nmMixedResults() => nmResults({
      nmCamera.physicalId:
          nmUpdated(nmCamera, 'c4', CameraReconnect.online, unverified: true),
      nmDevice.physicalId: nmUpdated(nmDevice, 'd1', CameraReconnect.missing),
      nmOffline.physicalId: const DeviceAddResult(
          candidate: nmOffline, outcome: DeviceAddOutcome.wifiFailed),
      nmBare.physicalId: const DeviceAddResult(
          candidate: nmBare,
          outcome: DeviceAddOutcome.failed,
          failure: DeviceProvisionFailure.notChecked),
    });

class NmWifiNames implements DeviceWifiNameStore {
  NmWifiNames([this.values = const {}]);
  final Map<(PairTargetKind, String), String> values;
  @override
  String? load(String account, PairTargetKind kind, String id) =>
      values[(kind, id)];
  @override
  Future<void> save(
      String account, PairTargetKind kind, String id, String ssid) async {}
  @override
  Stream<String?> watch(String account, PairTargetKind kind, String id) =>
      Stream.value(load(account, kind, id));
  @override
  Future<void> clearAll() async {}
}
