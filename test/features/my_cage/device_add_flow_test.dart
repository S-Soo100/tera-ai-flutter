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
  final wifiOnly = <bool>[];
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
      required bool Function() isCurrent,
      bool wifiOnly = false}) async {
    sent.add(candidate.physicalId);
    this.wifiOnly.add(wifiOnly);
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
  test('camera ambiguous receipt never claims registration or resends',
      () async {
    controller.select(camera);
    gateway.receipts[camera.physicalId] =
        const DeviceProvisionReceipt(wifiConnected: true);
    await controller.connect('home', 'password');
    expect(controller.state.results.values.single.outcome,
        DeviceAddOutcome.registrationPending);
    expect(controller.state.results.values.single.canRetry, isFalse);
    await controller.connect('home', 'password');
    expect(gateway.sent, [camera.physicalId]);
    expect(saved, isEmpty);
  });
  // 사육장은 UNPAIR 뒤 같은 device_id로 재등록돼 행이 늘지 않는다 — 등록
  // 대기면 다시 보내도 안전하다(2026-09-21, 기기가 pair를 안 한 사고).
  test('device registration pending keeps issue and can be re-provisioned',
      () async {
    controller.select(device);
    gateway.receipts[device.physicalId] = const DeviceProvisionReceipt(
        wifiConnected: true,
        issue: DeviceRegistrationIssue.pairFailed,
        issueDetail: '401');
    await controller.connect('home', 'password');
    final result = controller.state.results.values.single;
    expect(result.outcome, DeviceAddOutcome.registrationPending);
    expect(result.issue, DeviceRegistrationIssue.pairFailed);
    expect(result.issueDetail, '401');
    expect(result.canRetry, isTrue);
    gateway.receipts.clear();
    await controller.connect('home', 'password');
    expect(gateway.sent, [device.physicalId, device.physicalId]);
    expect(controller.state.results.values.single.outcome,
        DeviceAddOutcome.registered);
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

  /// 이미 등록된 카메라는 Wi-Fi만 바꾼다(2026-09-21). 카메라 펌웨어는 JWT가
  /// 오면 매번 새 camera_id로 등록해 cameras에 행이 하나씩 늘어났다. JWT를
  /// 빼면 pair를 호출하지 않고 NVS의 기존 camera_id로 재접속한다.
  group('이미 등록된 카메라', () {
    late Map<String, String> known;
    late List<String> forgotten;
    late DateTime? lastSeen;
    DeviceAddFlowController build() => DeviceAddFlowController(
        gateway: gateway,
        accountId: 'owner',
        isCurrent: () => active,
        token: () => 'jwt',
        namePrefix: (kind) => kind == PairTargetKind.device ? '사육장' : '카메라',
        names: () async => [],
        confirm: (kind, id) async => '${kind.name}-uuid',
        saveCredentials: (ssid, password) async {},
        readCredentials: () async => {},
        autoGroup: (owner, ids) async {
          groups.add(ids);
          return 'group';
        },
        knownCamera: (c) async => known[c.physicalId],
        registered: (c) async => known.containsKey(c.physicalId),
        rememberCamera: (c, id) async => known[c.physicalId] = id,
        forgetCamera: (c) async {
          forgotten.add(c.physicalId);
          known.remove(c.physicalId);
        },
        cameraLastSeen: (id) async => lastSeen,
        reconnectPoll: const Duration(milliseconds: 5),
        reconnectTimeout: const Duration(milliseconds: 40));
    setUp(() {
      controller.dispose();
      known = {};
      forgotten = [];
      lastSeen = null;
      controller = build();
    });

    test('새로 등록한 기기는 둘 다 기억하고 목록에 등록됨으로 표시한다', () async {
      controller.select(device);
      controller.select(camera);
      await controller.connect('home', 'password');
      expect(known,
          {device.physicalId: 'device-uuid', camera.physicalId: 'camera-uuid'});
      expect(gateway.wifiOnly, [false, false]);
      expect(
          controller.state.registered, {device.physicalId, camera.physicalId});
    });

    test('기억한 사육장이어도 Wi-Fi만 바꾸지 않고 새로 등록한다', () async {
      known[device.physicalId] = 'existing-device';
      controller.select(device);
      await controller.connect('home', 'password');
      expect(gateway.wifiOnly, [false]);
    });

    test('스캔된 기기 중 계정에 남아 있는 기억한 기기만 등록됨으로 표시한다', () async {
      known[camera.physicalId] = 'existing-camera';
      // setUp의 dispose가 이전 게이트웨이 스트림을 닫았다 — 새로 붙인다.
      controller.dispose();
      gateway = Gateway();
      controller = build();
      gateway.events.add([device, camera]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.registered, {camera.physicalId});
    });

    test('기억한 카메라는 JWT 없이 Wi-Fi만 보내고 기존 id를 쓴다', () async {
      known[camera.physicalId] = 'existing-camera';
      controller.select(camera);
      await controller.connect('home', 'password');
      final result = controller.state.results[PairTargetKind.camera]!;
      expect(gateway.wifiOnly, [true]);
      expect(result.outcome, DeviceAddOutcome.wifiUpdated);
      expect(result.registeredId, 'existing-camera');
    });

    test('Wi-Fi만 바꾼 카메라는 새 사육장과 자동으로 묶지 않는다', () async {
      known[camera.physicalId] = 'existing-camera';
      controller.select(device);
      controller.select(camera);
      await controller.connect('home', 'password');
      expect(groups, isEmpty);
    });

    test('Wi-Fi 실패는 다시 시도해도 안전하다', () async {
      known[camera.physicalId] = 'existing-camera';
      gateway.receipts[camera.physicalId] =
          const DeviceProvisionReceipt(wifiConnected: false);
      controller.select(camera);
      await controller.connect('home', 'password');
      expect(controller.state.results[PairTargetKind.camera]!.outcome,
          DeviceAddOutcome.wifiFailed);
    });

    test('다시 접속하면 재연결 확인으로 바뀐다', () async {
      known[camera.physicalId] = 'existing-camera';
      controller.select(camera);
      await controller.connect('home', 'password');
      expect(controller.state.results[PairTargetKind.camera]!.reconnect,
          CameraReconnect.waiting);
      lastSeen = DateTime.now().add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state.results[PairTargetKind.camera]!.reconnect,
          CameraReconnect.online);
    });

    test('끝내 접속하지 않으면 새 카메라로 등록할 수 있다', () async {
      known[camera.physicalId] = 'existing-camera';
      lastSeen = DateTime(2020);
      controller.select(camera);
      await controller.connect('home', 'password');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.state.results[PairTargetKind.camera]!.reconnect,
          CameraReconnect.missing);

      await controller.registerAsNew(PairTargetKind.camera);
      expect(forgotten, [camera.physicalId]);
      expect(controller.state.results, isEmpty);
      await controller.connect('home', 'password');
      expect(gateway.wifiOnly, [true, false]);
      expect(controller.state.results[PairTargetKind.camera]!.outcome,
          DeviceAddOutcome.registered);
    });
  });
}
