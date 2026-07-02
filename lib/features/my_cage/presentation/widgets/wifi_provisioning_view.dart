import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/ble_pairing_repository.dart';
import '../../domain/pair_target_kind.dart';
import '../../domain/wifi_access_point.dart';

// ── 상태 정의 ─────────────────────────────────────────────────────────────────

enum _Step {
  /// BLE 권한/어댑터 확인 → 기기 스캔
  bleScan,

  /// 기기 연결 + WiFi 스캔 요청 대기(SCANNING/SCAN_END)
  wifiScan,

  /// AP 목록에서 선택 + 비밀번호 입력
  credentials,

  /// SSID/PASS/CONNECT 전송 후 CONNECTING 대기
  connecting,

  /// WIFI_OK — 완료
  done,

  /// WIFI_FAIL / ERR / 연결 오류 — 실패
  failed,
}

/// bleScan 단계에서 errorMessage 외 추가 컨텍스트.
enum _ScanErrorKind {
  generic,
  permissionRequired,
  permissionDenied,
}

class _ProvState {
  final _Step step;
  final List<BleDeviceScanResult> bleResults;
  final BluetoothDevice? selectedDevice;
  final String? selectedDeviceName;
  final List<WifiAccessPoint> accessPoints;
  final WifiAccessPoint? selectedAp;

  /// 숨은 네트워크 직접 입력 모드.
  final bool manualSsid;
  final String? errorMessage;
  final _ScanErrorKind errorKind;

  const _ProvState({
    this.step = _Step.bleScan,
    this.bleResults = const [],
    this.selectedDevice,
    this.selectedDeviceName,
    this.accessPoints = const [],
    this.selectedAp,
    this.manualSsid = false,
    this.errorMessage,
    this.errorKind = _ScanErrorKind.generic,
  });

  _ProvState copyWith({
    _Step? step,
    List<BleDeviceScanResult>? bleResults,
    BluetoothDevice? selectedDevice,
    String? selectedDeviceName,
    List<WifiAccessPoint>? accessPoints,
    WifiAccessPoint? selectedAp,
    bool? manualSsid,
    String? errorMessage,
    _ScanErrorKind? errorKind,
  }) {
    return _ProvState(
      step: step ?? this.step,
      bleResults: bleResults ?? this.bleResults,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      selectedDeviceName: selectedDeviceName ?? this.selectedDeviceName,
      accessPoints: accessPoints ?? this.accessPoints,
      selectedAp: selectedAp ?? this.selectedAp,
      manualSsid: manualSsid ?? this.manualSsid,
      errorMessage: errorMessage ?? this.errorMessage,
      errorKind: errorKind ?? this.errorKind,
    );
  }

  /// errorMessage/selectedAp를 null로 명시적으로 지우는 사본.
  _ProvState clearedError() => _ProvState(
        step: step,
        bleResults: bleResults,
        selectedDevice: selectedDevice,
        selectedDeviceName: selectedDeviceName,
        accessPoints: accessPoints,
        selectedAp: selectedAp,
        manualSsid: manualSsid,
        errorMessage: null,
        errorKind: errorKind,
      );
}

// ── 공통 프로비저닝 뷰 ──────────────────────────────────────────────────────────

/// 사육장/카메라 공용 WiFi 프로비저닝 위젯.
///
/// - [kind]: BLE 광고 이름 필터 + 문구 결정.
/// - [titleKey]: 완료 화면 안내 문구 키(종류별로 다름).
/// - [onProvisioned]: WIFI_OK 수신 시 콜백 — 각 화면에서 목록 provider invalidate.
class WifiProvisioningView extends ConsumerStatefulWidget {
  const WifiProvisioningView({
    super.key,
    required this.kind,
    required this.doneSubtitleKey,
    this.onProvisioned,
  });

  final PairTargetKind kind;
  final String doneSubtitleKey;
  final VoidCallback? onProvisioned;

  @override
  ConsumerState<WifiProvisioningView> createState() =>
      _WifiProvisioningViewState();
}

class _WifiProvisioningViewState extends ConsumerState<WifiProvisioningView> {
  final _repo = BlePairingRepository();

  _ProvState _state = const _ProvState();

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<List<BleDeviceScanResult>>? _scanSub;
  StreamSubscription<BlePairingEvent>? _eventSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  @override
  void initState() {
    super.initState();
    _checkAdapterAndScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _eventSub?.cancel();
    _adapterSub?.cancel();
    _repo.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── 어댑터 상태 확인 + BLE 스캔 ──────────────────────────────────────────────

  Future<void> _checkAdapterAndScan() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanGranted =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final bleGranted = scanGranted && connectGranted;

    if (!bleGranted) {
      if (!mounted) return;
      final permanentlyDenied =
          (statuses[Permission.bluetoothScan]?.isPermanentlyDenied ?? false) ||
              (statuses[Permission.bluetoothConnect]?.isPermanentlyDenied ??
                  false);
      setState(() {
        _state = _state.copyWith(
          step: _Step.bleScan,
          errorMessage: permanentlyDenied
              ? 'ble_permission_denied'.tr()
              : 'ble_permission_required'.tr(),
          errorKind: permanentlyDenied
              ? _ScanErrorKind.permissionDenied
              : _ScanErrorKind.permissionRequired,
        );
      });
      return;
    }

    final adapterState = FlutterBluePlus.adapterStateNow;

    if (adapterState == BluetoothAdapterState.unauthorized) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          step: _Step.bleScan,
          errorMessage: 'ble_permission_denied'.tr(),
          errorKind: _ScanErrorKind.permissionDenied,
        );
      });
      return;
    }

    if (adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}

      if (!mounted) return;
      _adapterSub?.cancel();
      _adapterSub = FlutterBluePlus.adapterState.listen((s) {
        if (s == BluetoothAdapterState.on) {
          _adapterSub?.cancel();
          _startBleScan();
        }
      });
      _showAdapterOffBanner();
      return;
    }

    _startBleScan();
  }

  void _showAdapterOffBanner() {
    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _Step.bleScan,
        errorMessage: 'ble_adapter_off'.tr(),
        errorKind: _ScanErrorKind.generic,
      );
    });
  }

  void _startBleScan() {
    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _Step.bleScan,
        bleResults: [],
      ).clearedError();
    });

    _scanSub?.cancel();
    _scanSub = _repo.scanResults(widget.kind).listen(
      (results) {
        if (!mounted) return;
        setState(() {
          _state = _state.copyWith(bleResults: results);
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _state = _state.copyWith(
            errorMessage: 'ble_scan_error'.tr(args: [e.toString()]),
          );
        });
      },
    );

    _repo.startScan(kind: widget.kind).catchError((Object e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          errorMessage: 'ble_scan_error'.tr(args: [e.toString()]),
        );
      });
    });
  }

  // ── 기기 선택 → 연결 + WiFi 스캔 요청 ────────────────────────────────────────

  Future<void> _onDeviceSelected(BleDeviceScanResult result) async {
    await _repo.stopScan();
    await _scanSub?.cancel();

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _Step.wifiScan,
        selectedDevice: result.device,
        selectedDeviceName: result.name ?? result.device.remoteId.str,
        accessPoints: [],
      ).clearedError();
    });

    // 이벤트 구독 시작
    _eventSub?.cancel();
    _eventSub = _repo.events.listen(
      (event) {
        if (!mounted) return;
        _handleEvent(event);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _state = _state.copyWith(
            step: _Step.failed,
            errorMessage: 'ble_connection_error'.tr(args: [e.toString()]),
          );
        });
      },
    );

    try {
      await _repo.connect(result.device);
      await _repo.requestWifiScan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          step: _Step.failed,
          errorMessage: 'ble_connection_error'.tr(args: [e.toString()]),
        );
      });
    }
  }

  // ── WiFi 재스캔 ──────────────────────────────────────────────────────────────

  Future<void> _rescanWifi() async {
    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _Step.wifiScan,
        accessPoints: [],
      ).clearedError();
    });
    try {
      await _repo.requestWifiScan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          errorMessage: 'ble_scan_error'.tr(args: [e.toString()]),
        );
      });
    }
  }

  // ── AP 선택 → 자격증명 입력 ──────────────────────────────────────────────────

  void _onApSelected(WifiAccessPoint ap) {
    if (!mounted) return;
    _ssidController.text = ap.ssid;
    setState(() {
      _state = _state.copyWith(
        step: _Step.credentials,
        selectedAp: ap,
        manualSsid: false,
      );
    });
  }

  void _onManualSsid() {
    if (!mounted) return;
    _ssidController.clear();
    setState(() {
      _state = _state.copyWith(
        step: _Step.credentials,
        manualSsid: true,
      );
    });
  }

  // ── 자격증명 전송 ────────────────────────────────────────────────────────────

  Future<void> _submitCredentials() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(step: _Step.connecting).clearedError();
    });

    try {
      await _repo.sendWifiCredentials(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          step: _Step.failed,
          errorMessage: 'ble_connection_error'.tr(args: [e.toString()]),
        );
      });
    }
  }

  // ── 이벤트 핸들러 ────────────────────────────────────────────────────────────

  void _handleEvent(BlePairingEvent event) {
    switch (event) {
      case BleScanning():
        // 스캔 진행 중 — wifiScan 스켈레톤 유지.
        setState(() {
          _state = _state.copyWith(step: _Step.wifiScan, accessPoints: []);
        });

      case BleScanComplete(:final accessPoints):
        setState(() {
          _state = _state.copyWith(
            step: _Step.wifiScan,
            accessPoints: accessPoints,
          );
        });

      case BleNoApFound():
        setState(() {
          _state = _state.copyWith(
            step: _Step.wifiScan,
            accessPoints: [],
            errorMessage: 'ble_no_ap_found'.tr(),
          );
        });

      case BleScanFail():
        setState(() {
          _state = _state.copyWith(
            step: _Step.wifiScan,
            accessPoints: [],
            errorMessage: 'ble_scan_fail'.tr(),
          );
        });

      case BleSsidOk():
      case BlePassOk():
        // 진행 표시만 — connecting 화면 유지.
        break;

      case BleConnecting():
        setState(() {
          _state = _state.copyWith(step: _Step.connecting);
        });

      case BleWifiOk():
        setState(() {
          _state = _state.copyWith(step: _Step.done);
        });
        widget.onProvisioned?.call();

      case BleWifiFail():
        setState(() {
          _state = _state.copyWith(
            step: _Step.failed,
            errorMessage: 'ble_wifi_fail'.tr(),
          );
        });

      case BlePairingErr(:final code):
        setState(() {
          _state = _state.copyWith(
            step: _Step.failed,
            errorMessage: 'ble_err_code'.tr(args: [code]),
          );
        });

      case BlePairingUnknown():
        // 무시
        break;
    }
  }

  // ── 재시도 ────────────────────────────────────────────────────────────────────

  void _retry() {
    _eventSub?.cancel();
    _repo.disconnect();
    _ssidController.clear();
    _passwordController.clear();
    setState(() {
      _state = const _ProvState();
    });
    _startBleScan();
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_state.step) {
      _Step.bleScan => _BleScanBody(
          kind: widget.kind,
          results: _state.bleResults,
          errorMessage: _state.errorMessage,
          errorKind: _state.errorKind,
          onDeviceSelected: _onDeviceSelected,
          onRetry: _checkAdapterAndScan,
          onOpenSettings: openAppSettings,
        ),
      _Step.wifiScan => _WifiScanBody(
          deviceName: _state.selectedDeviceName ?? '',
          accessPoints: _state.accessPoints,
          errorMessage: _state.errorMessage,
          onApSelected: _onApSelected,
          onManualSsid: _onManualSsid,
          onRescan: _rescanWifi,
        ),
      _Step.credentials => _CredentialsBody(
          ssidController: _ssidController,
          passwordController: _passwordController,
          formKey: _formKey,
          manualSsid: _state.manualSsid,
          selectedAp: _state.selectedAp,
          onSubmit: _submitCredentials,
          onBack: _rescanWifi,
        ),
      _Step.connecting => _ConnectingBody(
          ssid: _ssidController.text.trim(),
        ),
      _Step.done => _DoneBody(
          subtitleKey: widget.doneSubtitleKey,
          onFinish: () => Navigator.of(context).maybePop(),
        ),
      _Step.failed => _FailedBody(
          message: _state.errorMessage ?? 'ble_pairing_failed'.tr(),
          onRetry: _retry,
        ),
    };
  }
}

// ── BLE 기기 스캔 화면 ───────────────────────────────────────────────────────────

class _BleScanBody extends StatelessWidget {
  const _BleScanBody({
    required this.kind,
    required this.results,
    required this.errorMessage,
    required this.errorKind,
    required this.onDeviceSelected,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final PairTargetKind kind;
  final List<BleDeviceScanResult> results;
  final String? errorMessage;
  final _ScanErrorKind errorKind;
  final ValueChanged<BleDeviceScanResult> onDeviceSelected;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitleKey = kind == PairTargetKind.camera
        ? 'ble_scanning_subtitle_camera'
        : 'ble_scanning_subtitle';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'ble_scanning_title'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitleKey.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          if (errorMessage != null)
            _ErrorBanner(
              message: errorMessage!,
              errorKind: errorKind,
              onRetry: onRetry,
              onOpenSettings: onOpenSettings,
            ),
          if (results.isEmpty && errorMessage == null) const _ListShimmer(),
          if (results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = results[i];
                  return _DeviceTile(
                    result: r,
                    onTap: () => onDeviceSelected(r),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          if (errorKind != _ScanErrorKind.permissionDenied)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('ble_rescan'.tr()),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.result, required this.onTap});

  final BleDeviceScanResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName = result.name ??
        'ble_unknown_device'
            .tr(args: [result.device.remoteId.str.substring(0, 8)]);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.sensors_rounded, color: cs.primary),
        title: Text(
          displayName,
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          result.device.remoteId.str,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_cellular_alt_rounded, size: 16),
            const SizedBox(width: 2),
            Text('${result.rssi} dBm', style: theme.textTheme.labelSmall),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── WiFi 목록 화면 ───────────────────────────────────────────────────────────────

class _WifiScanBody extends StatelessWidget {
  const _WifiScanBody({
    required this.deviceName,
    required this.accessPoints,
    required this.errorMessage,
    required this.onApSelected,
    required this.onManualSsid,
    required this.onRescan,
  });

  final String deviceName;
  final List<WifiAccessPoint> accessPoints;
  final String? errorMessage;
  final ValueChanged<WifiAccessPoint> onApSelected;
  final VoidCallback onManualSsid;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLoading = accessPoints.isEmpty && errorMessage == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'ble_select_network'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ble_scan_wifi'.tr(namedArgs: {'device': deviceName}),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          if (errorMessage != null)
            _ErrorBanner(
              message: errorMessage!,
              errorKind: _ScanErrorKind.generic,
              onRetry: onRescan,
              onOpenSettings: () {},
            ),
          if (isLoading) const _ListShimmer(),
          if (accessPoints.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: accessPoints.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final ap = accessPoints[i];
                  return _ApTile(ap: ap, onTap: () => onApSelected(ap));
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRescan,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('ble_rescan_wifi'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: onManualSsid,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text('ble_manual_ssid'.tr()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ApTile extends StatelessWidget {
  const _ApTile({required this.ap, required this.onTap});

  final WifiAccessPoint ap;
  final VoidCallback onTap;

  IconData get _signalIcon {
    switch (ap.signalLevel) {
      case WifiSignalLevel.strong:
        return Icons.signal_wifi_4_bar_rounded;
      case WifiSignalLevel.good:
        return Icons.network_wifi_3_bar_rounded;
      case WifiSignalLevel.fair:
        return Icons.network_wifi_2_bar_rounded;
      case WifiSignalLevel.weak:
        return Icons.network_wifi_1_bar_rounded;
    }
  }

  String get _signalLabelKey {
    switch (ap.signalLevel) {
      case WifiSignalLevel.strong:
        return 'ble_signal_strong';
      case WifiSignalLevel.good:
        return 'ble_signal_good';
      case WifiSignalLevel.fair:
        return 'ble_signal_fair';
      case WifiSignalLevel.weak:
        return 'ble_signal_weak';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(_signalIcon, color: cs.primary),
        title: Text(
          ap.ssid,
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _signalLabelKey.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

// ── 자격증명 입력 화면 ───────────────────────────────────────────────────────────

class _CredentialsBody extends StatefulWidget {
  const _CredentialsBody({
    required this.ssidController,
    required this.passwordController,
    required this.formKey,
    required this.manualSsid,
    required this.selectedAp,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController ssidController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final bool manualSsid;
  final WifiAccessPoint? selectedAp;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  State<_CredentialsBody> createState() => _CredentialsBodyState();
}

class _CredentialsBodyState extends State<_CredentialsBody> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'ble_enter_password'.tr(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.manualSsid
                  ? 'ble_manual_ssid_hint'.tr()
                  : 'ble_selected_network'
                      .tr(args: [widget.selectedAp?.ssid ?? '']),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),

            // SSID: 수동 모드일 때만 편집 가능. AP 선택 시엔 읽기 전용 표시.
            if (widget.manualSsid) ...[
              Text(
                'ble_form_ssid'.tr(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.ssidController,
                decoration: InputDecoration(
                  hintText: 'ble_form_ssid_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.wifi_rounded),
                ),
                maxLength: 32,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'ble_form_ssid_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'ble_form_password'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.passwordController,
              obscureText: !_showPassword,
              maxLength: 64,
              decoration: InputDecoration(
                hintText: 'ble_form_password_hint'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => widget.onSubmit(),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'ble_form_password_required'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onSubmit,
                icon: const Icon(Icons.wifi_rounded, size: 20),
                label: Text('ble_connect_wifi'.tr()),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onBack,
                child: Text('ble_back_to_list'.tr()),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── 연결 중 화면 (shimmer) ───────────────────────────────────────────────────────

class _ConnectingBody extends StatelessWidget {
  const _ConnectingBody({required this.ssid});

  final String ssid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_find_rounded, size: 64, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'ble_connecting'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ssid,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const _BarShimmer(),
        ],
      ),
    );
  }
}

// ── 완료 화면 ─────────────────────────────────────────────────────────────────

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.subtitleKey, required this.onFinish});

  final String subtitleKey;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_rounded,
              size: 44,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ble_wifi_connected'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitleKey.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onFinish,
              child: Text('ble_done_button'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 실패 화면 ─────────────────────────────────────────────────────────────────

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
          const SizedBox(height: 24),
          Text(
            'ble_failed_title'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text('ble_retry'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공용 에러 배너 ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.errorKind,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String message;
  final _ScanErrorKind errorKind;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDenied = errorKind == _ScanErrorKind.permissionDenied;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                ),
              ),
            ],
          ),
          if (isDenied) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: Text('ble_open_settings'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                ),
                child: Text('retry'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── shimmer 스켈레톤 ─────────────────────────────────────────────────────────────

class _ListShimmer extends StatelessWidget {
  const _ListShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surface,
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarShimmer extends StatelessWidget {
  const _BarShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surface,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
