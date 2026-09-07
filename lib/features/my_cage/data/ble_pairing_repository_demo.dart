import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../domain/pair_target_kind.dart';
import '../domain/wifi_access_point.dart';
import 'ble_pairing_repository.dart';

/// 디자이너 시연·화면 녹화용 데모 모드.
///
/// `flutter build ios --simulator --dart-define=BLE_DEMO=true`로 빌드했을 때만
/// true가 되며, 일반 빌드에서는 항상 false라 실 BLE 흐름에 영향이 없다.
/// 시뮬레이터에는 BLE가 없어 페어링 UI 전체 흐름을 보여줄 수 없으므로,
/// 실제 펌웨어 응답(SCANNING → SCAN_END → CONNECTING → WIFI_OK)을 지연을 섞어
/// 그대로 재현한다.
const bool kBleDemoMode = bool.fromEnvironment('BLE_DEMO');

class DemoBlePairingRepository extends BlePairingRepository {
  final StreamController<BlePairingEvent> _demoEvents =
      StreamController<BlePairingEvent>.broadcast();

  @override
  Stream<BlePairingEvent> get events => _demoEvents.stream;

  @override
  Stream<List<BleDeviceScanResult>> scanResults(PairTargetKind kind) async* {
    final name = kind.advertisedName;
    // 스캔 스켈레톤이 보이도록 잠시 비운 뒤 기기를 순차 발견.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    final first = BleDeviceScanResult(
      device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:01'),
      name: '$name-A1B2',
      rssi: -47,
    );
    yield [first];
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    yield [
      first,
      BleDeviceScanResult(
        device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:02'),
        name: '$name-C3D4',
        rssi: -68,
      ),
    ];
  }

  @override
  Future<void> startScan({
    required PairTargetKind kind,
    Duration timeout = const Duration(seconds: 15),
  }) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Stream<BluetoothAdapterState> get adapterState =>
      Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on);

  @override
  Future<void> connect(BluetoothDevice device) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  }

  @override
  Future<void> requestWifiScan() async {
    _demoEvents.add(BleScanning());
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    _demoEvents.add(
      BleScanComplete(
        accessPoints: const [
          WifiAccessPoint(no: 1, ssid: 'Vivnanaut_Home', rssi: -42, channel: 6),
          WifiAccessPoint(
              no: 2, ssid: 'KT_GiGA_5G_D21C', rssi: -58, channel: 44),
          WifiAccessPoint(no: 3, ssid: 'SK_WiFiGIGA88', rssi: -70, channel: 11),
          WifiAccessPoint(no: 4, ssid: 'iptime_office', rssi: -82, channel: 1),
        ],
      ),
    );
  }

  @override
  Future<void> sendWifiCredentials({
    required String ssid,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _demoEvents.add(BleConnecting());
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    _demoEvents.add(BleWifiOk());
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _demoEvents.close();
  }
}
