import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/ble_pairing_repository.dart';
import 'supabase_module_providers.dart';

// ── 상태 정의 ─────────────────────────────────────────────────────────────────

enum _PairingStep {
  /// BLE 권한/어댑터 확인 → 스캔
  scanning,

  /// 디바이스 선택 + WiFi/이름 입력 폼
  form,

  /// 데이터 전송 중 (NAME→JWT_CHUNK→WiFi 연결)
  sending,

  /// PAIR_OK 수신 — 완료
  done,

  /// WIFI_FAIL 또는 ERR — 실패
  failed,
}

class _PairingState {
  final _PairingStep step;
  final List<BleDeviceScanResult> scanResults;
  final BluetoothDevice? selectedDevice;
  final String? selectedDeviceName;
  final double jwtProgress; // 0.0 ~ 1.0
  final String? pairedDeviceId;
  final String? errorMessage;

  const _PairingState({
    this.step = _PairingStep.scanning,
    this.scanResults = const [],
    this.selectedDevice,
    this.selectedDeviceName,
    this.jwtProgress = 0.0,
    this.pairedDeviceId,
    this.errorMessage,
  });

  _PairingState copyWith({
    _PairingStep? step,
    List<BleDeviceScanResult>? scanResults,
    BluetoothDevice? selectedDevice,
    String? selectedDeviceName,
    double? jwtProgress,
    String? pairedDeviceId,
    String? errorMessage,
  }) {
    return _PairingState(
      step: step ?? this.step,
      scanResults: scanResults ?? this.scanResults,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      selectedDeviceName: selectedDeviceName ?? this.selectedDeviceName,
      jwtProgress: jwtProgress ?? this.jwtProgress,
      pairedDeviceId: pairedDeviceId ?? this.pairedDeviceId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── 화면 ──────────────────────────────────────────────────────────────────────

class DevicePairingScreen extends ConsumerStatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  ConsumerState<DevicePairingScreen> createState() =>
      _DevicePairingScreenState();
}

class _DevicePairingScreenState extends ConsumerState<DevicePairingScreen> {
  final _repo = BlePairingRepository();

  _PairingState _state = const _PairingState();

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
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
    _nameController.dispose();
    super.dispose();
  }

  // ── 어댑터 상태 확인 + 스캔 시작 ─────────────────────────────────────────────

  Future<void> _checkAdapterAndScan() async {
    final adapterState = FlutterBluePlus.adapterStateNow;

    if (adapterState != BluetoothAdapterState.on) {
      // 어댑터 켜질 때까지 대기
      _adapterSub = FlutterBluePlus.adapterState.listen((s) {
        if (s == BluetoothAdapterState.on) {
          _adapterSub?.cancel();
          _startScan();
        }
      });
      _showAdapterOffBanner();
      return;
    }

    _startScan();
  }

  void _showAdapterOffBanner() {
    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _PairingStep.scanning,
        errorMessage: 'ble_adapter_off'.tr(),
      );
    });
  }

  void _startScan() {
    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _PairingStep.scanning,
        scanResults: [],
        errorMessage: null,
      );
    });

    _scanSub?.cancel();
    _scanSub = _repo.scanResults.listen(
      (results) {
        if (!mounted) return;
        setState(() {
          _state = _state.copyWith(scanResults: results);
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

    _repo.startScan().catchError((Object e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          errorMessage: 'ble_scan_error'.tr(args: [e.toString()]),
        );
      });
    });
  }

  // ── 디바이스 선택 → 폼 단계 ──────────────────────────────────────────────────

  void _onDeviceSelected(BleDeviceScanResult scanResult) {
    _repo.stopScan();
    _scanSub?.cancel();

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        step: _PairingStep.form,
        selectedDevice: scanResult.device,
        selectedDeviceName: scanResult.name ?? scanResult.device.remoteId.str,
      );
    });
  }

  // ── 페어링 시작 ───────────────────────────────────────────────────────────────

  Future<void> _startPairing() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jwt == null || jwt.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ble_no_jwt'.tr())),
      );
      return;
    }

    final device = _state.selectedDevice;
    if (device == null) return;

    setState(() {
      _state = _state.copyWith(
        step: _PairingStep.sending,
        jwtProgress: 0.0,
        errorMessage: null,
      );
    });

    // 이벤트 구독
    _eventSub?.cancel();
    _eventSub = _repo.events.listen(
      (event) {
        if (!mounted) return;
        _handlePairingEvent(event);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _state = _state.copyWith(
            step: _PairingStep.failed,
            errorMessage: 'ble_connection_error'.tr(args: [e.toString()]),
          );
        });
      },
    );

    try {
      // BLE 연결
      await _repo.connect(device);

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(jwtProgress: 0.05);
      });

      // 데이터 전송
      await _repo.sendPairingData(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        jwt: jwt,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          step: _PairingStep.failed,
          errorMessage: 'ble_connection_error'.tr(args: [e.toString()]),
        );
      });
    }
  }

  void _handlePairingEvent(BlePairingEvent event) {
    switch (event) {
      case BlePairingNameOk():
        setState(() {
          _state = _state.copyWith(jwtProgress: 0.1);
        });

      case BlePairingJwtProgress(:final received, :final total):
        final progress = total > 0 ? (received / total) * 0.7 + 0.1 : 0.1;
        setState(() {
          _state = _state.copyWith(jwtProgress: progress.clamp(0.0, 0.8));
        });

      case BlePairingJwtOk():
        setState(() {
          _state = _state.copyWith(jwtProgress: 0.85);
        });

      case BlePairingWifiOk():
        setState(() {
          _state = _state.copyWith(jwtProgress: 0.95);
        });

      case BlePairingWifiFail():
        setState(() {
          _state = _state.copyWith(
            step: _PairingStep.failed,
            errorMessage: 'ble_wifi_fail'.tr(),
          );
        });

      case BlePairingErr(:final code):
        setState(() {
          _state = _state.copyWith(
            step: _PairingStep.failed,
            errorMessage: 'ble_err_code'.tr(args: [code]),
          );
        });

      case BlePairingPairOk(:final deviceId):
        setState(() {
          _state = _state.copyWith(
            step: _PairingStep.done,
            jwtProgress: 1.0,
            pairedDeviceId: deviceId,
          );
        });
        // 새 디바이스가 목록에 반영되도록 invalidate
        ref.invalidate(deviceListProvider);

      case BlePairingUnknown():
      // 무시
    }
  }

  // ── 재시도 ────────────────────────────────────────────────────────────────────

  void _retry() {
    _eventSub?.cancel();
    _repo.disconnect();
    setState(() {
      _state = const _PairingState();
    });
    _startScan();
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ble_pairing_title'.tr()),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state.step) {
      _PairingStep.scanning => _ScanningBody(
          results: _state.scanResults,
          errorMessage: _state.errorMessage,
          onDeviceSelected: _onDeviceSelected,
          onRetry: _startScan,
        ),
      _PairingStep.form => _FormBody(
          selectedDeviceName: _state.selectedDeviceName ?? '',
          ssidController: _ssidController,
          passwordController: _passwordController,
          nameController: _nameController,
          formKey: _formKey,
          onStart: _startPairing,
          onCancel: _retry,
        ),
      _PairingStep.sending => _SendingBody(
          progress: _state.jwtProgress,
          deviceName: _state.selectedDeviceName ?? '',
        ),
      _PairingStep.done => _DoneBody(
          deviceId: _state.pairedDeviceId ?? '',
          onFinish: () => context.pop(),
        ),
      _PairingStep.failed => _FailedBody(
          message: _state.errorMessage ?? 'ble_pairing_failed'.tr(),
          onRetry: _retry,
        ),
    };
  }
}

// ── 스캔 화면 ─────────────────────────────────────────────────────────────────

class _ScanningBody extends StatelessWidget {
  const _ScanningBody({
    required this.results,
    required this.errorMessage,
    required this.onDeviceSelected,
    required this.onRetry,
  });

  final List<BleDeviceScanResult> results;
  final String? errorMessage;
  final ValueChanged<BleDeviceScanResult> onDeviceSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
            'ble_scanning_subtitle'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          if (errorMessage != null)
            _ErrorBanner(message: errorMessage!, onRetry: onRetry),
          if (results.isEmpty && errorMessage == null)
            _ScanShimmer(),
          if (results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = results[i];
                  return _DeviceListTile(
                    result: r,
                    onTap: () => onDeviceSelected(r),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
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

class _ScanShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
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

class _DeviceListTile extends StatelessWidget {
  const _DeviceListTile({required this.result, required this.onTap});

  final BleDeviceScanResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName = result.name ??
        'ble_unknown_device'.tr(args: [result.device.remoteId.str.substring(0, 8)]);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.sensors_rounded,
          color: cs.primary,
        ),
        title: Text(
          displayName,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
            Text(
              '${result.rssi} dBm',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── 폼 화면 ───────────────────────────────────────────────────────────────────

class _FormBody extends StatefulWidget {
  const _FormBody({
    required this.selectedDeviceName,
    required this.ssidController,
    required this.passwordController,
    required this.nameController,
    required this.formKey,
    required this.onStart,
    required this.onCancel,
  });

  final String selectedDeviceName;
  final TextEditingController ssidController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
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
              'ble_form_title'.tr(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ble_form_device'.tr(args: [widget.selectedDeviceName]),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),

            // 디바이스 이름
            Text(
              'ble_form_device_name'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.nameController,
              decoration: InputDecoration(
                hintText: 'ble_form_device_name_hint'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'ble_form_device_name_required'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // WiFi SSID
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
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'ble_form_ssid_required'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // WiFi 비밀번호
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
                onPressed: widget.onStart,
                icon: const Icon(Icons.bluetooth_rounded, size: 20),
                label: Text('ble_start_pairing'.tr()),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onCancel,
                child: Text('ble_cancel'.tr()),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── 전송 중 화면 ──────────────────────────────────────────────────────────────

class _SendingBody extends StatelessWidget {
  const _SendingBody({required this.progress, required this.deviceName});

  final double progress;
  final String deviceName;

  String _stepLabel() {
    if (progress < 0.1) {
      return 'ble_step_connecting'.tr();
    }
    if (progress < 0.85) {
      return 'ble_step_sending_jwt'.tr(
        namedArgs: {'percent': '${(progress * 100).toInt()}'},
      );
    }
    if (progress < 0.95) {
      return 'ble_step_connecting_wifi'.tr();
    }
    return 'ble_step_pairing'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_connected_rounded,
            size: 64,
            color: cs.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'ble_sending_title'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            deviceName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          Text(
            _stepLabel(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 완료 화면 ─────────────────────────────────────────────────────────────────

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.deviceId, required this.onFinish});

  final String deviceId;
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
              Icons.check_rounded,
              size: 48,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ble_done_title'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ble_done_subtitle'.tr(),
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
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: cs.error,
          ),
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

// ── 에러 배너 ─────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
}
