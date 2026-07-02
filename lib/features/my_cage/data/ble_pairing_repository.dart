import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../domain/pair_target_kind.dart';
import '../domain/wifi_access_point.dart';

// ── UUID 상수 (기존과 동일) ────────────────────────────────────────────────────

/// 기기 BLE 서비스 UUID (scan 필터, 사육장·카메라 공통)
const _kServiceUuid = '12345678-1234-1234-1234-123456789abc';

/// RX characteristic (write): SCAN / SSID / PASS / CONNECT 전달
const _kRxUuid = '12345678-1234-1234-1234-123456789abe';

/// TX characteristic (notify): 기기 응답 수신
const _kTxUuid = '12345678-1234-1234-1234-123456789abd';

/// BLE write 사이 대기 시간
const _kWriteDelayMs = 60;

// ── sealed 이벤트 클래스 ──────────────────────────────────────────────────────────

sealed class BlePairingEvent {}

/// WiFi 스캔 완료 — 확정된 AP 목록.
class BleScanComplete extends BlePairingEvent {
  final List<WifiAccessPoint> accessPoints;
  BleScanComplete({required this.accessPoints});
}

/// WiFi 스캔 진행 중 (SCANNING 수신).
class BleScanning extends BlePairingEvent {}

/// 검색된 AP 없음 (NO_AP_FOUND).
class BleNoApFound extends BlePairingEvent {}

/// WiFi 스캔 실패 (SCAN_FAIL).
class BleScanFail extends BlePairingEvent {}

/// SSID 저장됨 (SSID_OK).
class BleSsidOk extends BlePairingEvent {}

/// 비밀번호 저장됨 (PASS_OK).
class BlePassOk extends BlePairingEvent {}

/// WiFi 연결 시도 중 (CONNECTING).
class BleConnecting extends BlePairingEvent {}

/// WiFi 연결 성공 (WIFI_OK).
class BleWifiOk extends BlePairingEvent {}

/// WiFi 연결 실패 (WIFI_FAIL).
class BleWifiFail extends BlePairingEvent {}

/// 에러 수신 (ERR:<code>).
class BlePairingErr extends BlePairingEvent {
  final String code;
  BlePairingErr({required this.code});
}

/// 알 수 없는 TX 메시지 (무시용).
class BlePairingUnknown extends BlePairingEvent {
  final String raw;
  BlePairingUnknown({required this.raw});
}

// ── 스캔 결과 (BLE 기기 목록) ──────────────────────────────────────────────────

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

  /// WiFi 스캔 AP 누적 버퍼. SCAN_END에 확정 후 비운다.
  final List<WifiAccessPoint> _apBuffer = [];

  /// TX notify 이벤트 스트림 (외부 소비).
  Stream<BlePairingEvent> get events => _eventController.stream;

  // ── BLE 기기 스캔 ────────────────────────────────────────────────────────────

  /// serviceUuid 필터로 광고 스캔하되, [kind]의 광고 이름과 일치하는 기기만 방출.
  /// Stream을 listen하다 dispose 시 자동 정리.
  Stream<List<BleDeviceScanResult>> scanResults(PairTargetKind kind) {
    return FlutterBluePlus.onScanResults.map((results) {
      return results
          .map((r) {
            final advName = r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : (r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : null);
            return BleDeviceScanResult(
              device: r.device,
              name: advName,
              rssi: r.rssi,
            );
          })
          .where((r) => kind.matchesAdvName(r.name))
          .toList();
    });
  }

  Future<void> startScan({
    required PairTargetKind kind,
    Duration timeout = const Duration(seconds: 15),
  }) async {
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

  /// BluetoothAdapterState 스트림 — 어댑터 off 감지용.
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
      if (msg.isEmpty) return;
      _dispatchTxMessage(msg);
    });
  }

  // ── TX 메시지 파싱 → 이벤트 디스패치 ──────────────────────────────────────────

  void _dispatchTxMessage(String msg) {
    // ── 스캔 흐름 ──
    if (msg == 'SCANNING') {
      _apBuffer.clear();
      _eventController.add(BleScanning());
      return;
    }
    if (msg.startsWith('SCAN:')) {
      // SCAN:<count> — 개수 통지. 버퍼는 이미 SCANNING에서 초기화됨.
      _apBuffer.clear();
      return;
    }
    if (msg.startsWith('AP:')) {
      final ap = _parseApLine(msg);
      if (ap != null) _apBuffer.add(ap);
      return;
    }
    if (msg == 'SCAN_END') {
      _eventController.add(
        BleScanComplete(accessPoints: List.unmodifiable(_apBuffer)),
      );
      return;
    }
    if (msg == 'NO_AP_FOUND') {
      _apBuffer.clear();
      _eventController.add(BleNoApFound());
      return;
    }
    if (msg == 'SCAN_FAIL') {
      _apBuffer.clear();
      _eventController.add(BleScanFail());
      return;
    }

    // ── 설정 흐름 ──
    if (msg == 'SSID_OK') {
      _eventController.add(BleSsidOk());
      return;
    }
    if (msg == 'PASS_OK') {
      _eventController.add(BlePassOk());
      return;
    }

    // ── 연결 흐름 ──
    if (msg == 'CONNECTING') {
      _eventController.add(BleConnecting());
      return;
    }
    if (msg == 'WIFI_OK') {
      _eventController.add(BleWifiOk());
      return;
    }
    if (msg == 'WIFI_FAIL') {
      _eventController.add(BleWifiFail());
      return;
    }

    // ── 에러 ──
    if (msg.startsWith('ERR:')) {
      _eventController.add(BlePairingErr(code: msg.substring(4)));
      return;
    }

    _eventController.add(BlePairingUnknown(raw: msg));
  }

  /// `AP:<no>,<ssid>,<rssi>,<channel>` 파싱.
  ///
  /// ssid에 콤마가 포함될 수 있으므로: `AP:` 접두 제거 후 콤마로 split한 뒤
  /// **맨 앞=no, 맨 뒤=channel, 뒤에서 두 번째=rssi**로 고정하고,
  /// **가운데 나머지 전체를 콤마로 재조합해 ssid**로 복원한다.
  /// 최소 4개 토큰이 없으면(파싱 불가) null.
  WifiAccessPoint? _parseApLine(String msg) {
    final body = msg.substring(3); // 'AP:' 제거
    final parts = body.split(',');
    if (parts.length < 4) return null;

    final no = int.tryParse(parts.first.trim());
    final channel = int.tryParse(parts.last.trim());
    final rssi = int.tryParse(parts[parts.length - 2].trim());
    if (no == null || channel == null || rssi == null) return null;

    // 가운데(인덱스 1 ~ length-3)를 콤마로 재조합 → ssid.
    final ssid = parts.sublist(1, parts.length - 2).join(',').trim();
    if (ssid.isEmpty) return null;

    return WifiAccessPoint(
      no: no,
      ssid: ssid,
      rssi: rssi,
      channel: channel,
    );
  }

  // ── WiFi 스캔 요청 ────────────────────────────────────────────────────────────

  Future<void> requestWifiScan() async {
    final rx = _requireRx();
    _apBuffer.clear();
    await _write(rx, 'SCAN');
  }

  // ── WiFi 자격증명 전송 (SSID → PASS → CONNECT) ────────────────────────────────

  Future<void> sendWifiCredentials({
    required String ssid,
    required String password,
  }) async {
    final rx = _requireRx();

    await _write(rx, 'SSID:$ssid');
    await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));

    await _write(rx, 'PASS:$password');
    await Future<void>.delayed(const Duration(milliseconds: _kWriteDelayMs));

    await _write(rx, 'CONNECT');
  }

  BluetoothCharacteristic _requireRx() {
    final rx = _rxChar;
    if (rx == null) {
      throw StateError('기기에 연결되지 않았거나 RX characteristic이 없습니다');
    }
    return rx;
  }

  Future<void> _write(BluetoothCharacteristic char, String text) async {
    await char.write(utf8.encode(text), withoutResponse: false);
  }

  // ── 연결 해제 + 리소스 정리 ───────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _txSubscription?.cancel();
    _txSubscription = null;
    _apBuffer.clear();

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
