import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vivanaut/features/my_cage/data/ble_pairing_repository.dart';
import 'package:vivanaut/features/my_cage/data/device_add_ble_adapter.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

class _Repo extends BlePairingRepository {
  BluetoothAdapterState adapter = BluetoothAdapterState.on;
  int scans = 0;
  @override
  Stream<List<BleDeviceScanResult>> scanResults(PairTargetKind kind) =>
      const Stream.empty();
  @override
  Stream<BluetoothAdapterState> get adapterState => Stream.value(adapter);
  @override
  Future<void> startScan(
      {required PairTargetKind kind,
      Duration timeout = const Duration(seconds: 15)}) async {
    scans++;
  }

  @override
  Future<void> stopScan() async {}
  @override
  Future<void> dispose() async {}
}

// permission_handler 채널 값: denied 0 · granted 1 · restricted 2 · permanentlyDenied 4
const _granted = 1, _restricted = 2, _permanent = 4;
const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late DeviceAddBleAdapter adapter;
  late List<List<int>> asked;
  late int answer;

  setUp(() {
    repo = _Repo();
    adapter = DeviceAddBleAdapter(repository: repo);
    asked = [];
    answer = _granted;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method != 'requestPermissions') return null;
      final ids = (call.arguments as List).cast<int>();
      asked.add(ids);
      return {for (final id in ids) id: answer};
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    adapter.dispose();
  });

  Future<DeviceAddScanProblem?> scan() async {
    try {
      await adapter.startScan();
      return null;
    } on DeviceAddScanException catch (e) {
      return e.problem;
    }
  }

  group('iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('asks only Permission.bluetooth and scans when allowed', () async {
      expect(await scan(), isNull);
      expect(asked, [
        [Permission.bluetooth.value]
      ]);
      expect(repo.scans, 1);
    });

    test('denied in the popup → settings guidance, no scan', () async {
      answer = _permanent;
      expect(await scan(), DeviceAddScanProblem.permission);
      expect(repo.scans, 0);
    });

    test('restricted (스크린 타임 등) → settings guidance', () async {
      answer = _restricted;
      expect(await scan(), DeviceAddScanProblem.permission);
    });

    test('CoreBluetooth unauthorized is a permission problem, not BT off',
        () async {
      repo.adapter = BluetoothAdapterState.unauthorized;
      expect(await scan(), DeviceAddScanProblem.permission);
    });

    test('bluetooth off stays bluetoothOff', () async {
      repo.adapter = BluetoothAdapterState.off;
      expect(await scan(), DeviceAddScanProblem.bluetoothOff);
    });
  });

  group('Android (unchanged)', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('asks nearby-devices + location and scans', () async {
      expect(await scan(), isNull);
      expect(asked, [
        [
          Permission.bluetoothScan.value,
          Permission.bluetoothConnect.value,
          Permission.locationWhenInUse.value
        ]
      ]);
      expect(repo.scans, 1);
    });

    test('permanently denied → settings guidance', () async {
      answer = _permanent;
      expect(await scan(), DeviceAddScanProblem.permission);
      expect(repo.scans, 0);
    });
  });
}
