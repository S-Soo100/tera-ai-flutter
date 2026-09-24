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
    // 카메라부터 보낸다 — 켜진 뒤 3분만 검색된다(2026-09-25).
    expect(gateway.sent,
        [camera.physicalId, device.physicalId, camera.physicalId]);
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
  // 사육장은 등록 대기면 다시 보낼 수 있다(2026-09-21, 기기가 pair를 안 한
  // 사고). ⚠️ 다시 보내면 서버가 새 device_id로 새 행을 만든다(2026-09-25 운영
  // 확인) — "같은 행으로 잡힌다"던 옛 주석은 틀렸다.
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

    // BLE 회신은 힌트일 뿐(2026-09-24): 카메라는 Wi-Fi에 붙으면 재부팅하며
    // BLE를 끊어 WIFI_OK가 유실된다 — 실제론 붙은 카메라를 실패로 표시했다.
    // CONNECT 뒤 BLE가 끊긴 영수증(카메라 재부팅으로 WIFI_OK 유실).
    const droppedAfterConnect = DeviceProvisionReceipt(
        wifiConnected: false, retrySafe: true, connectSent: true);

    test('CONNECT 뒤 BLE가 끊겨도 last_seen_at이 새로 갱신되면 연결 완료다', () async {
      known[camera.physicalId] = 'existing-camera';
      gateway.receipts[camera.physicalId] = droppedAfterConnect;
      controller.select(camera);
      await controller.connect('home', 'password');
      final result = controller.state.results[PairTargetKind.camera]!;
      expect(result.outcome, DeviceAddOutcome.wifiUpdated);
      expect(result.wifiConnected, isFalse);
      expect(result.reconnect, CameraReconnect.waiting);
      expect(result.canRetry, isFalse); // 확인 중엔 다시 연결 버튼 없음
      lastSeen = DateTime.now().add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state.results[PairTargetKind.camera]!.reconnect,
          CameraReconnect.online);
    });

    // 리뷰 지적(2026-09-24): 옛 Wi-Fi로 계속 오던 하트비트가 새 접속으로 읽히면
    // 안 된다 — 영수증 뒤 읽은 기준값보다 '새로운' last_seen_at만 접속이다.
    // 폰 시계로 미래(서버 시계 앞섬)인 값이어도 기준값과 같으면 아니다.
    test('영수증 전부터 있던 last_seen_at(시계 오차로 미래여도)은 접속이 아니다',
        () async {
      known[camera.physicalId] = 'existing-camera';
      lastSeen = DateTime.now().add(const Duration(minutes: 5));
      gateway.receipts[camera.physicalId] = droppedAfterConnect;
      controller.select(camera);
      await controller.connect('home', 'password');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.state.results[PairTargetKind.camera]!.reconnect,
          CameraReconnect.missing);
    });

    test('기준값보다 새 하트비트가 오면 그때 접속이다', () async {
      known[camera.physicalId] = 'existing-camera';
      final stale = DateTime.now().add(const Duration(minutes: 5));
      lastSeen = stale;
      gateway.receipts[camera.physicalId] = droppedAfterConnect;
      controller.select(camera);
      await controller.connect('home', 'password');
      lastSeen = stale.add(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state.results[PairTargetKind.camera]!.reconnect,
          CameraReconnect.online);
    });

    test('기기가 WIFI_FAIL로 실패를 확정하면 서버를 보지 않고 즉시 실패다', () async {
      known[camera.physicalId] = 'existing-camera';
      lastSeen = DateTime.now(); // 옛 Wi-Fi 하트비트가 살아 있어도
      gateway.receipts[camera.physicalId] = const DeviceProvisionReceipt(
          wifiConnected: false,
          retrySafe: true,
          connectSent: true,
          wifiRejected: true);
      controller.select(camera);
      await controller.connect('home', 'password');
      final result = controller.state.results[PairTargetKind.camera]!;
      expect(result.outcome, DeviceAddOutcome.wifiFailed);
      expect(result.canRetry, isTrue);
    });

    test('CONNECT를 보내기 전에 끊겼으면 기기는 시도조차 안 했다 — 즉시 실패', () async {
      known[camera.physicalId] = 'existing-camera';
      lastSeen = DateTime.now();
      gateway.receipts[camera.physicalId] =
          const DeviceProvisionReceipt(wifiConnected: false, retrySafe: true);
      controller.select(camera);
      await controller.connect('home', 'password');
      expect(controller.state.results[PairTargetKind.camera]!.outcome,
          DeviceAddOutcome.wifiFailed);
    });

    test('BLE 끊김 뒤 끝내 안 붙으면 실패로 다시 연결할 수 있다', () async {
      known[camera.physicalId] = 'existing-camera';
      lastSeen = DateTime(2020);
      gateway.receipts[camera.physicalId] = droppedAfterConnect;
      controller.select(camera);
      await controller.connect('home', 'password');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final result = controller.state.results[PairTargetKind.camera]!;
      expect(result.reconnect, CameraReconnect.missing);
      expect(result.unconfirmedFailed, isTrue);
      expect(result.canRetry, isTrue);
      // 다시 연결하면 Wi-Fi만 다시 보낸다(새 등록 아님).
      gateway.receipts[camera.physicalId] =
          const DeviceProvisionReceipt(wifiConnected: true);
      await controller.connect('home', 'password');
      expect(gateway.wifiOnly, [true, true]);
      expect(controller.state.results[PairTargetKind.camera]!.wifiConnected,
          isTrue);
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

  // ── 2026-09-25 흐름 점검 ─────────────────────────────────────────────

  test('CONNECT 전 블루투스 실패는 비밀번호 오류(wifiFailed)가 아니라 연결 실패', () async {
    controller.select(camera);
    gateway.receipts[camera.physicalId] = const DeviceProvisionReceipt(
        wifiConnected: false,
        retrySafe: true,
        failure: DeviceProvisionFailure.ble);
    await controller.connect('home', 'password');
    final result = controller.state.results.values.single;
    expect(result.outcome, DeviceAddOutcome.failed);
    expect(result.failure, DeviceProvisionFailure.ble);
    expect(result.canRetry, isTrue);
  });

  test('기기가 WIFI_FAIL로 거절하면 여전히 Wi-Fi 실패', () async {
    controller.select(camera);
    gateway.receipts[camera.physicalId] = const DeviceProvisionReceipt(
        wifiConnected: false,
        retrySafe: true,
        connectSent: true,
        wifiRejected: true);
    await controller.connect('home', 'password');
    expect(controller.state.results.values.single.outcome,
        DeviceAddOutcome.wifiFailed);
  });

  test('등록 확인할 것이 없으면 다시 확인은 false — 화면이 알린다', () async {
    controller.select(device);
    gateway.receipts[device.physicalId] = const DeviceProvisionReceipt(
        wifiConnected: true,
        connectSent: true,
        issue: DeviceRegistrationIssue.noPairReply);
    await controller.connect('home', 'password');
    expect(controller.state.results.values.single.outcome,
        DeviceAddOutcome.registrationPending);
    expect(await controller.recheckRegistration(), isFalse);
  });

  test('새 카메라로 등록 — 새 등록이 성공한 뒤에만 옛 카메라 행을 해제한다', () async {
    final unlinked = <String>[];
    final known = <String, String>{};
    final c = DeviceAddFlowController(
        gateway: gateway,
        accountId: 'owner',
        isCurrent: () => true,
        token: () => 'jwt',
        namePrefix: (_) => '카메라',
        names: () async => [],
        confirm: (kind, id) async => 'camera-new',
        saveCredentials: (_, __) async {},
        readCredentials: () async => {},
        autoGroup: (_, __) async => 'group',
        knownCamera: (candidate) async => known[candidate.physicalId],
        forgetCamera: (candidate) async => known.remove(candidate.physicalId),
        rememberCamera: (candidate, id) async => known[candidate.physicalId] = id,
        cameraLastSeen: (_) async => null,
        unlinkCamera: (id) async => unlinked.add(id),
        reconnectPoll: const Duration(milliseconds: 1),
        reconnectTimeout: Duration.zero);
    addTearDown(c.dispose);
    known[camera.physicalId] = 'camera-old';
    c.select(camera);
    // Wi-Fi만 변경 → 끝내 안 붙음(missing).
    gateway.receipts[camera.physicalId] = const DeviceProvisionReceipt(
        wifiConnected: false, retrySafe: true, connectSent: true);
    await c.connect('home', 'password');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.state.results[PairTargetKind.camera]?.reconnect,
        CameraReconnect.missing);
    await c.registerAsNew(PairTargetKind.camera);
    expect(unlinked, isEmpty, reason: '새 등록 전에 지우면 실패 시 카메라가 사라진다');
    gateway.receipts[camera.physicalId] =
        const DeviceProvisionReceipt(wifiConnected: true, hardwareId: 'mqtt');
    await c.connect('home', 'password');
    expect(c.state.results[PairTargetKind.camera]?.registeredId, 'camera-new');
    expect(unlinked, ['camera-old']);
  });

  test('새 카메라 등록이 다시 확인으로 늦게 확인돼도 옛 행을 해제한다', () async {
    final unlinked = <String>[];
    final known = <String, String>{'physical-b': 'camera-old'};
    var confirmCalls = 0;
    final c = DeviceAddFlowController(
        gateway: gateway,
        accountId: 'owner',
        isCurrent: () => true,
        token: () => 'jwt',
        namePrefix: (_) => '카메라',
        names: () async => [],
        // 첫 확인은 아직 행이 없고, 다시 확인에서 보인다.
        confirm: (kind, id) async => confirmCalls++ == 0 ? null : 'camera-new',
        saveCredentials: (_, __) async {},
        readCredentials: () async => {},
        autoGroup: (_, __) async => 'group',
        knownCamera: (candidate) async => known[candidate.physicalId],
        forgetCamera: (candidate) async => known.remove(candidate.physicalId),
        rememberCamera: (candidate, id) async => known[candidate.physicalId] = id,
        cameraLastSeen: (_) async => null,
        unlinkCamera: (id) async => unlinked.add(id),
        reconnectPoll: const Duration(milliseconds: 1),
        reconnectTimeout: Duration.zero);
    addTearDown(c.dispose);
    c.select(camera);
    gateway.receipts[camera.physicalId] = const DeviceProvisionReceipt(
        wifiConnected: false, retrySafe: true, connectSent: true);
    await c.connect('home', 'password');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await c.registerAsNew(PairTargetKind.camera);
    gateway.receipts[camera.physicalId] =
        const DeviceProvisionReceipt(wifiConnected: true, hardwareId: 'mqtt');
    await c.connect('home', 'password');
    expect(c.state.results[PairTargetKind.camera]?.outcome,
        DeviceAddOutcome.registrationPending);
    expect(unlinked, isEmpty);
    expect(await c.recheckRegistration(), isTrue);
    expect(unlinked, ['camera-old']);
  });
}
