import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/wifi_access_point.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';

const device = DeviceAddCandidate(
    physicalId: 'physical-a',
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -40);
const camera = DeviceAddCandidate(
    physicalId: 'physical-b',
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM',
    rssi: -42);

class Gateway implements DeviceAddGateway {
  final events = StreamController<List<DeviceAddCandidate>>.broadcast();
  final sent = <String>[];
  final receipts = <String, DeviceProvisionReceipt>{};
  Completer<void>? pending;
  @override
  Stream<List<DeviceAddCandidate>> get scanResults => events.stream;
  @override
  Future<void> startScan() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<List<WifiAccessPoint>> networks(DeviceAddCandidate candidate) async =>
      [];
  @override
  Future<DeviceProvisionReceipt> provision(DeviceAddCandidate candidate,
      {required String ssid,
      required String password,
      required String name,
      required String jwt,
      required Future<void> Function() onWifiConnected,
      required bool Function() isCurrent}) async {
    sent.add(candidate.physicalId);
    await pending?.future;
    final receipt = receipts[candidate.physicalId] ??
        const DeviceProvisionReceipt(wifiConnected: true, hardwareId: 'mqtt');
    if (receipt.wifiConnected) await onWifiConnected();
    return receipt;
  }

  @override
  Future<void> dispose() => events.close();
}

void main() {
  late Gateway gateway;
  late DeviceAddFlowController controller;
  var active = true;
  var storageFails = false;
  late List<String> saved;
  late List<Map<PairTargetKind, String>> groups;
  setUp(() {
    gateway = Gateway();
    active = true;
    storageFails = false;
    saved = [];
    groups = [];
    controller = DeviceAddFlowController(
        gateway: gateway,
        accountId: 'owner',
        isCurrent: () => active,
        token: () => 'jwt',
        namePrefix: (kind) => kind == PairTargetKind.device ? '사육장' : '카메라',
        names: () async => [],
        confirm: (kind, id) async => '${kind.name}-uuid',
        saveCredentials: (ssid, password) async {
          if (storageFails) throw StateError('secure store unavailable');
          saved.add(ssid);
        },
        readCredentials: () async => {},
        autoGroup: (owner, ids) async {
          groups.add(ids);
          return 'group';
        });
  });
  tearDown(() => controller.dispose());
  test(
      'one physical device per kind, preserves successful device on partial retry',
      () async {
    controller.select(device);
    controller.select(camera);
    gateway.receipts[camera.physicalId] =
        const DeviceProvisionReceipt(wifiConnected: false, retrySafe: true);
    await controller.connect('home', 'password');
    expect(controller.state.results[PairTargetKind.device]?.registeredId,
        'device-uuid');
    expect(groups, isEmpty);
    gateway.receipts.clear();
    await controller.connect('home', 'password');
    expect(gateway.sent,
        [device.physicalId, camera.physicalId, camera.physicalId]);
    expect(groups.single.values.toSet(), {'device-uuid', 'camera-uuid'});
  });
  test('WiFi-only and ambiguous receipt never claim registration or resend',
      () async {
    controller.select(device);
    gateway.receipts[device.physicalId] =
        const DeviceProvisionReceipt(wifiConnected: true);
    await controller.connect('home', 'password');
    expect(controller.state.results.values.single.outcome,
        DeviceAddOutcome.registrationPending);
    await controller.connect('home', 'password');
    expect(gateway.sent, [device.physicalId]);
    expect(saved, isEmpty);
  });
  test(
      'account change during WIFI_OK blocks storage, confirmation and next device',
      () async {
    controller.select(device);
    controller.select(camera);
    controller.remember(true);
    gateway.pending = Completer<void>();
    final work = controller.connect('home', 'password');
    await Future<void>.delayed(Duration.zero);
    active = false;
    gateway.pending!.complete();
    await work;
    expect(saved, isEmpty);
    expect(groups, isEmpty);
    expect(gateway.sent.length, 1);
    expect(controller.state.results, isEmpty);
  });
  test('remember requires explicit opt-in and WIFI_OK', () async {
    controller.select(device);
    controller.remember(true);
    await controller.connect('home', 'password');
    expect(saved, ['home']);
  });
  test('optional secure storage failure preserves registration confirmation',
      () async {
    storageFails = true;
    controller.select(device);
    controller.remember(true);
    await controller.connect('home', 'password');
    expect(controller.state.results.values.single.outcome,
        DeviceAddOutcome.registered);
    expect(saved, isEmpty);
  });
  test('continued addition groups only current flow confirmed IDs', () async {
    controller.select(device);
    await controller.connect('home', 'password');
    await controller.continueAdding();
    controller.select(camera);
    await controller.connect('home', 'password');
    expect(gateway.sent, [device.physicalId, camera.physicalId]);
    expect(groups.single.length, 2);
  });
}
