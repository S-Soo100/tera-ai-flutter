import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── UUID 상수 (APP_INTEGRATION.md §6 기준) ──────────────────────────────────────

/// 디바이스 BLE 서비스 UUID (scan 필터)
const _kServiceUuid = '12345678-1234-1234-1234-123456789abc';

/// RX characteristic (write): SSID/PASS/JWT 등 전달
const _kRxUuid = '12345678-1234-1234-1234-123456789abe';

/// TX characteristic (notify): 디바이스 응답 수신
const _kTxUuid = '12345678-1234-1234-1234-123456789abd';

/// JWT 청크 최대 크기 (정책 §6: 200자 이내)
const _kJwtChunkSize = 200;

/// BLE write 사이 대기 시간 (정책 §6: 50ms)
const _kWriteDelayMs = 50;

// ── sealed 이벤트 클래스 ──────────────────────────────────────────────────────────

sealed class BlePairingEvent {}

/// NAME 저장됨
class BlePairingNameOk extends BlePairingEvent {}

/// JWT 청크 전송 진행 상황
class BlePairingJwtProgress extends BlePairingEvent {
  final int received;
  final int total;
  BlePairingJwtProgress({required this.received, required this.total});
}

/// JWT 전송 완료
class BlePairingJwtOk extends BlePairingEvent {
  final int total;
  BlePairingJwtOk({required this.total});
}

/// WiFi 연결 성공
class BlePairingWifiOk extends BlePairingEvent {}

/// WiFi 연결 실패
class BlePairingWifiFail extends BlePairingEvent {}

/// 에러 수신
class BlePairingErr extends BlePairingEvent {
  final String code;
  BlePairingErr({required this.code});
}

/// 페어링 완료 — device_id 포함
class BlePairingPairOk extends BlePairingEvent {
  final String deviceId;
  BlePairingPairOk({required this.deviceId});
}

/// 알 수 없는 TX 메시지 (무시용)
class BlePairingUnknown extends BlePairingEvent {
  final String raw;
  BlePairingUnknown({required this.raw});
}

// ── 스캔 결과 ────────────────────────────────────────────────────────────────────

class BleDeviceScanResult {
  final BluetoothDevice device;
  final String? name;
  final int rssi;

  const BleDeviceScanResult({
    required this.device,
    required this.name,
    required this.rssi,
  });
}

// ── Repository ───────────────────────────────────────────────────────────────────

class BlePairingRepository {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _txSubscription;
  final StreamController<BlePairingEvent> _eventController =
      StreamController<BlePairingEvent>.broadcast();

  /// TX notify 이벤트 스트림 (외부 소비)
  Stream<BlePairingEvent> get events => _eventController.stream;

  // ── 스캔 ──────────────────────────────────────────────────────────────────────

  /// serviceUuid 필터로 ESP32 BLE 광고 스캔.
  /// Stream을 listen하다 dispose 시 자동 정리.
  Stream<List<BleDeviceScanResult>> get scanResults {
    return FlutterBluePlus.onScanResults.map(
      (results) => results
          .map(
            (r) => BleDeviceScanResult(
              device: r.device,
              name: r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : null,
              rssi: r.rssi,
            ),
          )
          .toList(),
    );
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    await FlutterBluePlus.startScan(
      withServices: [Guid(_kServiceUuid)],
      timeout: timeout,
    );
  }

  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  /// BluetoothAdapterState 스트림 — 어댑터 off 감지용
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  // ── 연결 + 서비스 탐색 ────────────────────────────────────────────────────────

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();

    _connectedDevice = device;
    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 20),
      mtu: 512,
    );

    final services = await device.discoverServices();
    final targetService = services.firstWhere(
      (s) => s.uuid == Guid(_kServiceUuid),
      orElse: () => throw StateError('서비스를 찾을 수 없습니다: $_kServiceUuid'),
    );

    _rxChar = targetService.characteristics.firstWhere(
      (c) => c.uuid == Guid(_kRxUuid),
      orElse: () => throw StateError('RX characteristic 없음: $_kRxUuid'),
    );

    _txChar = targetService.characteristics.firstWhere(
      (c) => c.uuid == Guid(_kTxUuid),
      orElse: () => throw StateError('TX characteristic 없음: $_kTxUuid'),
    );

    // TX notify 구독
    await _txChar!.setNotifyValue(true);
    _txSubscription = _txChar!.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      final msg = utf8.decode(data, allowMalformed: true).trim();
      _dispatchTxMessage(msg);
    });
  }

  // ── TX 메시지 파싱 → 이벤트 디스패치 ──────────────────────────────────────────

  void _dispatchTxMessage(String msg) {
    if (msg == 'NAME_OK') {
      _eventController.add(BlePairingNameOk());
      return;
    }
    if (msg == 'WIFI_OK') {
      _eventController.add(BlePairingWifiOk());
      return;
    }
    if (msg == 'WIFI_FAIL') {
      _eventController.add(BlePairingWifiFail());
      return;
    }
    // JWT_CHUNK <received>/<total>
    if (msg.startsWith('JWT_CHUNK ')) {
      final parts = msg.substring(10).split('/');
      if (parts.length == 2) {
        final received = int.tryParse(parts[0]);
        final total = int.tryParse(parts[1]);
        if (received != null && total != null) {
          _eventController.add(
            BlePairingJwtProgress(received: received, total: total),
          );
          return;
        }
      }
    }
    // JWT_OK <total>
    if (msg.startsWith('JWT_OK ')) {
      final total = int.tryParse(msg.substring(7).trim());
      if (total != null) {
        _eventController.add(BlePairingJwtOk(total: total));
        return;
      }
    }
    // PAIR_OK <device_id>
    if (msg.startsWith('PAIR_OK ')) {
      final deviceId = msg.substring(8).trim();
      _eventController.add(BlePairingPairOk(deviceId: deviceId));
      return;
    }
    // ERR:<code>
    if (msg.startsWith('ERR:')) {
      final code = msg.substring(4);
      _eventController.add(BlePairingErr(code: code));
      return;
    }
    _eventController.add(BlePairingUnknown(raw: msg));
  }

  // ── 페어링 데이터 전송 (정책 §6 RX write 시퀀스) ─────────────────────────────

  Future<void> sendPairingData({
    required String ssid,
    required String password,
    required String name,
    required String jwt,
  }) async {
    final rx = _rxChar;
    if (rx == null) {
      throw StateError('디바이스에 연결되지 않았거나 RX characteristic이 없습니다');
    }

    await _write(rx, 'SSID:$ssid');
    await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));

    await _write(rx, 'PASS:$password');
    await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));

    await _write(rx, 'NAME:$name');
    await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));

    // JWT 청크 전송
    await _write(rx, 'JWT_BEGIN ${jwt.length}');
    await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));

    final chunks = (jwt.length / _kJwtChunkSize).ceil();
    for (int i = 0; i < chunks; i++) {
      final start = i * _kJwtChunkSize;
      final end = min(start + _kJwtChunkSize, jwt.length);
      final chunk = jwt.substring(start, end);
      await _write(rx, 'JWT:$chunk');
      await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));
    }

    await _write(rx, 'CONNECT');
  }

  Future<void> _write(BluetoothCharacteristic char, String text) async {
    await char.write(utf8.encode(text), withoutResponse: false);
  }

  // ── 연결 해제 + 리소스 정리 ───────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _txSubscription?.cancel();
    _txSubscription = null;

    if (_connectedDevice != null) {
      try {
        await _txChar?.setNotifyValue(false);
      } catch (_) {}
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }

    _rxChar = null;
    _txChar = null;
    _connectedDevice = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await stopScan();
    await _eventController.close();
  }
}
