import 'dart:async';
import 'dart:math' show min;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/device_add_flow.dart';
import '../domain/pair_target_kind.dart';
import '../domain/wifi_access_point.dart';
import 'ble_pairing_repository.dart';

/// Physical BLE identity is retained independently of advertising names.
class DeviceAddBleAdapter implements DeviceAddGateway {
  DeviceAddBleAdapter(
      {BlePairingRepository? repository,
      this.replyTimeout = const Duration(seconds: 8),
      this.wifiTimeout = const Duration(seconds: 60),
      this.registrationTimeout = const Duration(seconds: 25)})
      : _repo = repository ?? BlePairingRepository() {
    for (final kind in PairTargetKind.values) {
      _subscriptions.add(_repo.scanResults(kind).listen((rows) {
        for (final row in rows) {
          final id = row.device.remoteId.str;
          _devices[id] = row;
          _candidates[id] = DeviceAddCandidate(
              physicalId: id,
              kind: kind,
              name: row.name ?? kind.advertisedName,
              rssi: row.rssi);
        }
        if (!_scan.isClosed) _scan.add(List.unmodifiable(_candidates.values));
      }, onError: (Object error) {
        if (!_scan.isClosed) _scan.addError(error);
      }));
    }
  }
  final BlePairingRepository _repo;
  final Duration replyTimeout, wifiTimeout, registrationTimeout;
  final _scan = StreamController<List<DeviceAddCandidate>>.broadcast();
  final List<StreamSubscription<List<BleDeviceScanResult>>> _subscriptions = [];
  final Map<String, BleDeviceScanResult> _devices = {};
  final Map<String, DeviceAddCandidate> _candidates = {};
  bool _disposed = false;
  @override
  Stream<List<DeviceAddCandidate>> get scanResults => _scan.stream;

  @override
  Future<void> startScan() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse
    ].request();
    if (_disposed) return;
    if (permissions[Permission.bluetoothScan]?.isPermanentlyDenied == true ||
        permissions[Permission.bluetoothConnect]?.isPermanentlyDenied == true) {
      throw StateError('Bluetooth permission denied');
    }
    final adapter = await _repo.adapterState
        .firstWhere((value) => value != BluetoothAdapterState.unknown)
        .timeout(replyTimeout);
    if (_disposed) return;
    if (adapter != BluetoothAdapterState.on) {
      throw StateError('Bluetooth unavailable');
    }
    _candidates.clear();
    _scan.add(const []);
    await _repo.startScan(kind: PairTargetKind.device);
  }

  @override
  Future<void> stopScan() => _repo.stopScan();

  Future<void> _connect(DeviceAddCandidate candidate) async {
    final row = _devices[candidate.physicalId];
    if (row == null || _disposed) {
      throw StateError('Physical device unavailable');
    }
    await _repo.suppressCredentialLogging();
    await _repo.disconnect();
    await _repo.connect(row.device);
  }

  @override
  Future<List<WifiAccessPoint>> networks(DeviceAddCandidate candidate) async {
    await _connect(candidate);
    final inbox = _BleInbox(_repo.events);
    try {
      await _repo.requestWifiScan();
      final reply = await inbox.take(
          (e) =>
              e is BleScanComplete ||
              e is BleNoApFound ||
              e is BleScanFail ||
              e is BlePairingErr,
          const Duration(seconds: 30));
      if (reply is BleScanComplete) return reply.accessPoints;
      if (reply is BleNoApFound) return const [];
      throw StateError('WiFi scan failed');
    } finally {
      await inbox.dispose();
      await _repo.disconnect();
    }
  }

  @override
  Future<DeviceProvisionReceipt> provision(DeviceAddCandidate candidate,
      {required String ssid,
      required String password,
      required String name,
      required String jwt,
      required Future<void> Function() onWifiConnected,
      required bool Function() isCurrent,
      bool wifiOnly = false}) async {
    bool connectSent = false;
    bool wifi = false;
    _BleInbox? inbox;
    try {
      await _connect(candidate);
      inbox = _BleInbox(_repo.events);
      Future<void> command(String value) async {
        if (_disposed || !isCurrent()) throw StateError('Account changed');
        await _repo.sendPairingCommand(value);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // 사육장은 저장된 서버 자격증명을 먼저 지워 삭제·타 계정 기기도 이 자리에서
      // 재등록되게 한다(펌웨어 요청서 2026-09-17 §2-2). 미지원 펌웨어의
      // ERR:UNKNOWN_CMD·무응답은 삼키고 진행한다. 카메라는 §2-3 전이라 보내지
      // 않는다 — 플래시 때 개발 계정으로 된 등록만 지워질 수 있다.
      // 이미 등록된 카메라의 Wi-Fi 변경: NAME·JWT를 빼면 펌웨어가 pair를
      // 호출하지 않고(app_ble_prov.c `have_jwt` 조건) 재부팅 뒤 NVS의 기존
      // camera_id로 재접속한다. 등록이 일어날 수 없으니 실패는 늘 재시도 안전.
      if (wifiOnly) {
        await command('SSID:$ssid');
        await command('PASS:$password');
        connectSent = true;
        await command('CONNECT');
        final result = await inbox.take(
            (e) =>
                e is BleWifiOk ||
                e is BleWifiFail ||
                e is BlePairOk ||
                e is BlePairFail ||
                e is BlePairingErr,
            wifiTimeout);
        if (result is! BleWifiOk) {
          return const DeviceProvisionReceipt(
              wifiConnected: false, retrySafe: true);
        }
        wifi = true;
        if (isCurrent()) await onWifiConnected();
        return const DeviceProvisionReceipt(
            wifiConnected: true, retrySafe: true);
      }
      if (candidate.kind == PairTargetKind.device) {
        await command('UNPAIR');
        try {
          await inbox.take(
              (e) => e is BleUnpairOk || e is BlePairingErr, replyTimeout);
        } on TimeoutException {/* Legacy firmware ignores UNPAIR. */}
      }
      // Establish capability before disclosing a current-account JWT. Old
      // firmware rejects NAME; no claim API or fabricated registration follows.
      await command('SSID:$ssid');
      await command('PASS:$password');
      await command('NAME:$name');
      bool supportsRegistration = false;
      try {
        final reply = await inbox.take(
            (e) => e is BleNameOk || e is BlePairingErr, replyTimeout);
        if (reply is BleNameOk) supportsRegistration = true;
        if (reply is BlePairingErr && reply.code != 'UNKNOWN_CMD') {
          throw StateError('Name rejected');
        }
      } on TimeoutException {/* Legacy firmware can silently ignore NAME. */}
      if (supportsRegistration) {
        if (jwt.isEmpty) throw StateError('Session unavailable');
        await command('JWT_BEGIN ${jwt.length}');
        final begin = await inbox.take(
            (e) => e is BleJwtBeginOk || e is BlePairingErr, replyTimeout);
        if (begin is! BleJwtBeginOk) throw StateError('JWT_BEGIN rejected');
        final chunkSize = _repo.jwtChunkSize;
        for (var i = 0; i < jwt.length; i += chunkSize) {
          await command(
              'JWT:${jwt.substring(i, min(i + chunkSize, jwt.length))}');
        }
        final ack = await inbox.take(
            (e) => e is BleJwtOk || e is BlePairingErr, replyTimeout);
        if (ack is! BleJwtOk || ack.length != jwt.length) {
          throw StateError('JWT not acknowledged');
        }
      }
      if (_disposed || !isCurrent()) throw StateError('Account changed');
      // Set before the write: even an interrupted write may reach the device.
      connectSent = true;
      await command('CONNECT');
      final result = await inbox.take(
          (e) =>
              e is BleWifiOk ||
              e is BleWifiFail ||
              e is BlePairOk ||
              e is BlePairFail ||
              e is BlePairingErr,
          wifiTimeout);
      if (result is BleWifiFail) {
        return const DeviceProvisionReceipt(
            wifiConnected: false, retrySafe: true);
      }
      if (result is BlePairOk && supportsRegistration) {
        // PAIR_OK implies server access but remember requires explicit WIFI_OK.
        return DeviceProvisionReceipt(
            wifiConnected: false, hardwareId: result.hardwareId);
      }
      if (result is! BleWifiOk) {
        return const DeviceProvisionReceipt(wifiConnected: false);
      }
      wifi = true;
      if (isCurrent()) await onWifiConnected();
      if (!supportsRegistration) {
        return const DeviceProvisionReceipt(wifiConnected: true);
      }
      // PAIR_FAIL은 등록 확인 대기를 일찍 끝낸다(등록 대기로 남아 재확인 가능).
      final pair = await inbox.take(
          (e) => e is BlePairOk || e is BlePairFail || e is BlePairingErr,
          registrationTimeout);
      return DeviceProvisionReceipt(
          wifiConnected: true,
          hardwareId: pair is BlePairOk ? pair.hardwareId : null);
    } catch (_) {
      return DeviceProvisionReceipt(
          wifiConnected: wifi, retrySafe: wifiOnly || !connectSent);
    } finally {
      await inbox?.dispose();
      await _repo.disconnect();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _repo.dispose();
    await _scan.close();
  }
}

/// Buffer notifications before writes; adjacent WIFI_OK/PAIR_OK notifications
/// cannot be lost between await boundaries. Never log their payloads.
class _BleInbox {
  _BleInbox(Stream<BlePairingEvent> events) {
    _subscription = events.listen((event) {
      _events.add(event);
      _wake?.complete();
      _wake = null;
    });
  }
  late final StreamSubscription<BlePairingEvent> _subscription;
  final List<BlePairingEvent> _events = [];
  Completer<void>? _wake;
  Future<BlePairingEvent> take(
      bool Function(BlePairingEvent) predicate, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      final index = _events.indexWhere(predicate);
      if (index >= 0) return _events.removeAt(index);
      final remaining = end.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('BLE reply timeout');
      }
      final wake = _wake ??= Completer<void>();
      await wake.future.timeout(remaining);
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
