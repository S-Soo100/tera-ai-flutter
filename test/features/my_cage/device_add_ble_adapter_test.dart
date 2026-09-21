import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/ble_pairing_repository.dart';
import 'package:vivanaut/features/my_cage/data/device_add_ble_adapter.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

class Repository extends BlePairingRepository {
  final tx = StreamController<BlePairingEvent>.broadcast(sync: true);
  final commands = <String>[];
  bool modern = true,
      sendPair = true,
      wifiFail = false,
      pairFail = false,
      rejectJwtBegin = false,
      loggingSuppressed = false;
  int jwtLength = 0;
  int chunkLimit = 200;
  @override
  int get jwtChunkSize => chunkLimit;
  String jwt = '';
  @override
  Stream<BlePairingEvent> get events => tx.stream;
  @override
  Stream<List<BleDeviceScanResult>> scanResults(PairTargetKind kind) =>
      Stream.value(kind == PairTargetKind.device
          ? [
              BleDeviceScanResult(
                  device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
                  name: 'terra-iot',
                  rssi: -40)
            ]
          : []);
  @override
  Future<void> connect(BluetoothDevice device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> suppressCredentialLogging() async {
    loggingSuppressed = true;
  }

  @override
  Future<void> sendPairingCommand(String command) async {
    expect(loggingSuppressed, isTrue);
    commands.add(command);
    if (command.startsWith('NAME:')) {
      tx.add(modern ? BleNameOk() : BlePairingErr(code: 'UNKNOWN_CMD'));
    }
    if (command == 'UNPAIR') {
      tx.add(modern ? BleUnpairOk() : BlePairingErr(code: 'UNKNOWN_CMD'));
    }
    if (command.startsWith('JWT_BEGIN ')) {
      jwtLength = int.parse(command.substring(10));
      tx.add(rejectJwtBegin ? BlePairingErr(code: 'BAD_LEN') : BleJwtBeginOk());
    }
    if (command.startsWith('JWT:')) {
      jwt += command.substring(4);
      if (jwt.length == jwtLength) tx.add(BleJwtOk(jwtLength));
    }
    if (command == 'CONNECT') {
      tx.add(wifiFail ? BleWifiFail() : BleWifiOk());
      if (!wifiFail && modern && pairFail) tx.add(BlePairFail('401'));
      if (!wifiFail && modern && sendPair && !pairFail) {
        tx.add(BlePairOk('firmware-mqtt-id'));
      }
    }
  }

  @override
  Future<void> dispose() => tx.close();
}

void main() {
  late Repository repo;
  late DeviceAddBleAdapter adapter;
  late DeviceAddCandidate candidate;
  setUp(() async {
    repo = Repository();
    adapter = DeviceAddBleAdapter(
        repository: repo,
        registrationTimeout: const Duration(milliseconds: 10));
    candidate =
        (await adapter.scanResults.firstWhere((rows) => rows.isNotEmpty))
            .single;
  });
  tearDown(() => adapter.dispose());
  test(
      'modern writes confirmed wire format, <=200 chunks and buffers adjacent WIFI/PAIR',
      () async {
    var remembered = 0;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'x' * 450,
        onWifiConnected: () async {
          remembered++;
        },
        isCurrent: () => true);
    expect(
        repo.commands
            .where((c) => c.startsWith('JWT:'))
            .map((c) => c.length - 4),
        [200, 200, 50]);
    expect(repo.commands, [
      'UNPAIR',
      'SSID:home',
      'PASS:pw',
      'NAME:사육장 1',
      'JWT_BEGIN 450',
      'JWT:${'x' * 200}',
      'JWT:${'x' * 200}',
      'JWT:${'x' * 50}',
      'CONNECT'
    ]);
    expect(result.hardwareId, 'firmware-mqtt-id');
    expect(result.wifiConnected, true);
    expect(remembered, 1);
  });
  test('negotiated smaller MTU keeps every JWT chunk inside the payload',
      () async {
    repo.chunkLimit = 17;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'x' * 40,
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(
        repo.commands
            .where((c) => c.startsWith('JWT:'))
            .map((c) => c.length - 4),
        [17, 17, 6]);
    expect(result.hardwareId, 'firmware-mqtt-id');
  });
  test('legacy receives no JWT and WIFI_OK remains registration pending',
      () async {
    repo.modern = false;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(repo.commands.any((c) => c.startsWith('JWT')), false);
    expect(result.wifiConnected, true);
    expect(result.hardwareId, isNull);
    expect(result.retrySafe, false);
  });
  test('lost PAIR_OK cannot become a safe reconnect', () async {
    repo.sendPair = false;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(result.wifiConnected, true);
    expect(result.retrySafe, false);
    expect(repo.commands.where((c) => c == 'CONNECT').length, 1);
  });
  test('explicit WIFI_FAIL is retryable and never saves', () async {
    repo.wifiFail = true;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {
          fail('failed WiFi saved');
        },
        isCurrent: () => true);
    expect(result.retrySafe, true);
    expect(result.wifiConnected, false);
  });
  test('account changed before writes sends no JWT or CONNECT', () async {
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {
          fail('stale account saved');
        },
        isCurrent: () => false);
    expect(repo.commands, isEmpty);
    expect(result.hardwareId, isNull);
  });
  test('legacy UNPAIR rejection is swallowed and pairing proceeds', () async {
    repo.modern = false;
    await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(repo.commands.first, 'UNPAIR');
    expect(repo.commands, contains('CONNECT'));
  });
  test('camera never receives UNPAIR', () async {
    final camera = DeviceAddCandidate(
        physicalId: candidate.physicalId,
        kind: PairTargetKind.camera,
        name: 'FB2_P4_CAM',
        rssi: -40);
    await adapter.provision(camera,
        ssid: 'home',
        password: 'pw',
        name: '카메라 1',
        jwt: 'secret',
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(repo.commands, isNot(contains('UNPAIR')));
  });
  test('rejected JWT_BEGIN never sends CONNECT and stays retry-safe', () async {
    repo.rejectJwtBegin = true;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(repo.commands.any((c) => c.startsWith('JWT:')), false);
    expect(repo.commands, isNot(contains('CONNECT')));
    expect(result.retrySafe, true);
  });
  test('PAIR_FAIL ends registration wait without an id', () async {
    repo.pairFail = true;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '사육장 1',
        jwt: 'secret',
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(result.wifiConnected, true);
    expect(result.hardwareId, isNull);
  });

  test('Wi-Fi 변경은 SSID·PASS·CONNECT만 보낸다 — NAME·JWT가 없으면 펌웨어가 등록하지 않는다',
      () async {
    final camera = DeviceAddCandidate(
        physicalId: candidate.physicalId,
        kind: PairTargetKind.camera,
        name: 'FB2_P4_CAM_A1B2',
        rssi: -40);
    var remembered = 0;
    final result = await adapter.provision(camera,
        ssid: 'home',
        password: 'pw',
        name: '카메라 1',
        jwt: 'secret',
        wifiOnly: true,
        onWifiConnected: () async {
          remembered++;
        },
        isCurrent: () => true);
    expect(repo.commands, ['SSID:home', 'PASS:pw', 'CONNECT']);
    expect(result.wifiConnected, true);
    expect(result.hardwareId, isNull);
    expect(remembered, 1);
  });
  test('Wi-Fi 변경 실패는 다시 시도해도 안전하다', () async {
    repo.wifiFail = true;
    final result = await adapter.provision(candidate,
        ssid: 'home',
        password: 'pw',
        name: '카메라 1',
        jwt: 'secret',
        wifiOnly: true,
        onWifiConnected: () async {},
        isCurrent: () => true);
    expect(result.wifiConnected, false);
    expect(result.retrySafe, true);
  });
}
