import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/device_add_ble_adapter.dart';
import '../data/device_add_registration_repository.dart';
import '../data/wifi_credentials_store.dart';
import '../domain/device_add_flow.dart';
import '../domain/pair_target_kind.dart';
import '../domain/redesign_management.dart';

final deviceAddAccountProvider = Provider<String?>(
    (ref) => ref.watch(currentUserProvider.select((u) => u?.id)));
final deviceAddGatewayFactoryProvider =
    Provider<DeviceAddGateway Function()>((ref) => DeviceAddBleAdapter.new);
final deviceAddAutoGroupProvider = Provider<DeviceAddAutoGroup>((ref) =>
    (account, ids) async => throw StateError('Atomic grouping unavailable'));
final deviceAddCompletedProvider = Provider<void Function()>((ref) => () {});
final deviceAddFlowProvider = StateNotifierProvider.autoDispose
    .family<DeviceAddFlowController, DeviceAddState, Object>((ref, key) {
  final account = ref.watch(deviceAddAccountProvider);
  final client = Supabase.instance.client;
  final registration = DeviceAddRegistrationRepository(client);
  final credentials = WifiCredentialsStore();
  final group = ref.watch(deviceAddAutoGroupProvider);
  final completed = ref.watch(deviceAddCompletedProvider);
  final gatewayFactory = ref.watch(deviceAddGatewayFactoryProvider);
  var active = true;
  ref.onDispose(() => active = false);
  return DeviceAddFlowController(
      gateway: gatewayFactory(),
      accountId: account ?? '',
      isCurrent: () =>
          active && account != null && client.auth.currentUser?.id == account,
      token: () => client.auth.currentSession?.accessToken ?? '',
      namePrefix: (kind) => (kind == PairTargetKind.device
              ? 'device_add_device'
              : 'device_add_camera')
          .tr(),
      names: () => registration.names(account!),
      confirm: (kind, id) => registration.confirm(account!, kind, id),
      saveCredentials: (ssid, password) =>
          credentials.save(ssid, password, accountId: account!),
      readCredentials: () => credentials.readAll(accountId: account!),
      autoGroup: group,
      completed: completed);
});

class DeviceAddFlowController extends StateNotifier<DeviceAddState> {
  DeviceAddFlowController(
      {required DeviceAddGateway gateway,
      required String accountId,
      required bool Function() isCurrent,
      required String Function() token,
      required String Function(PairTargetKind) namePrefix,
      required Future<List<String>> Function() names,
      required Future<String?> Function(PairTargetKind, String) confirm,
      required Future<void> Function(String, String) saveCredentials,
      required Future<Map<String, String>> Function() readCredentials,
      required DeviceAddAutoGroup autoGroup,
      void Function()? completed})
      : _gateway = gateway,
        _account = accountId,
        _isCurrent = isCurrent,
        _token = token,
        _names = names,
        _namePrefix = namePrefix,
        _confirm = confirm,
        _save = saveCredentials,
        _read = readCredentials,
        _group = autoGroup,
        _completed = completed,
        super(const DeviceAddState()) {
    _scan = gateway.scanResults.listen((rows) {
      if (_active) state = state.copyWith(candidates: List.unmodifiable(rows));
    }, onError: (Object _) {
      if (_active) {
        state = state.copyWith(busy: false, errorKey: 'device_add_scan_error');
      }
    });
  }
  final DeviceAddGateway _gateway;
  final String _account;
  final bool Function() _isCurrent;
  final String Function() _token;
  final String Function(PairTargetKind) _namePrefix;
  final Future<List<String>> Function() _names;
  final Future<String?> Function(PairTargetKind, String) _confirm;
  final Future<void> Function(String, String) _save;
  final Future<Map<String, String>> Function() _read;
  final DeviceAddAutoGroup _group;
  final void Function()? _completed;
  late final StreamSubscription<List<DeviceAddCandidate>> _scan;
  Timer? _scanTimer;
  bool get _active => mounted && _isCurrent();
  Future<void> scan() async {
    if (!_active || state.busy) return;
    state = state.copyWith(step: DeviceAddStep.scan, busy: true);
    try {
      await _gateway.startScan();
      if (!_active) return;
      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), () {
        if (_active && state.step == DeviceAddStep.scan) {
          state = state.copyWith(busy: false);
        }
      });
    } catch (_) {
      if (_active) {
        state = state.copyWith(busy: false, errorKey: 'device_add_scan_error');
      }
    }
  }

  void select(DeviceAddCandidate candidate) {
    if (!_active || state.results[candidate.kind]?.canRetry == false) return;
    final selected = {...state.selected};
    if (selected[candidate.kind]?.physicalId == candidate.physicalId) {
      selected.remove(candidate.kind);
    } else {
      selected[candidate.kind] = candidate;
    }
    state = state.copyWith(selected: Map.unmodifiable(selected));
  }

  Future<void> loadNetworks() async {
    if (!_active || state.selected.isEmpty) return;
    _scanTimer?.cancel();
    state = state.copyWith(step: DeviceAddStep.networks, busy: true);
    try {
      await _gateway.stopScan();
      if (!_active) return;
      final networks = await _gateway.networks(state.selected.values.first);
      if (_active) {
        state =
            state.copyWith(networks: List.unmodifiable(networks), busy: false);
      }
    } catch (_) {
      if (_active) {
        state =
            state.copyWith(busy: false, errorKey: 'device_add_network_error');
      }
    }
  }

  void chooseNetwork(String ssid) {
    if (_active) {
      state = state.copyWith(
          step: DeviceAddStep.credentials, ssid: ssid, busy: false);
    }
  }

  void remember(bool value) {
    if (_active) state = state.copyWith(remember: value);
  }

  void togglePassword() {
    if (_active) state = state.copyWith(showPassword: !state.showPassword);
  }

  Future<String?> savedPassword(String ssid) async {
    if (!_active) return null;
    final all = await _read();
    return _active ? all[ssid] : null;
  }

  Future<void> connect(String ssid, String password) async {
    if (!_active || state.busy && state.step != DeviceAddStep.scan) return;
    if (ssid.isEmpty ||
        utf8.encode(ssid).length > 32 ||
        utf8.encode(password).length > 64 ||
        ssid.contains('\n') ||
        ssid.contains('\r') ||
        password.contains('\n') ||
        password.contains('\r')) {
      state = state.copyWith(errorKey: 'device_add_credentials_invalid');
      return;
    }
    final pending = state.selected.values
        .where((c) => state.results[c.kind]?.canRetry != false)
        .toList();
    if (pending.isEmpty) return;
    final remember = state.remember;
    state =
        state.copyWith(step: DeviceAddStep.connecting, busy: true, ssid: ssid);
    try {
      final names = await _names();
      if (!_active) return;
      for (final candidate in pending) {
        if (!_active) return;
        state = state.copyWith(activePhysicalId: candidate.physicalId);
        final prefix = _namePrefix(candidate.kind);
        final name = nextManagementName(prefix, names);
        names.add(name);
        final receipt = await _gateway.provision(candidate,
            ssid: ssid,
            password: password,
            name: name,
            jwt: _token(),
            isCurrent: () => _active,
            onWifiConnected: () async {
              if (_active && remember) {
                try {
                  await _save(ssid, password);
                } catch (_) {
                  // Remembering is optional; do not discard a firmware ACK.
                }
              }
            });
        if (!_active) return;
        String? id;
        if (receipt.hardwareId case final hardware?) {
          try {
            id = await _confirm(candidate.kind, hardware);
          } catch (_) {/* Keep pending. */}
        }
        if (!_active) return;
        final result = DeviceAddResult(
            candidate: candidate,
            wifiConnected: receipt.wifiConnected,
            hardwareId: receipt.hardwareId,
            registeredId: id,
            outcome: id != null
                ? DeviceAddOutcome.registered
                : receipt.retrySafe
                    ? DeviceAddOutcome.wifiFailed
                    : DeviceAddOutcome.registrationPending);
        state = state.copyWith(
            results:
                Map.unmodifiable({...state.results, candidate.kind: result}));
        if (id != null) _completed?.call();
      }
      if (!_active) return;
      state = state.copyWith(step: DeviceAddStep.results, busy: false);
      await groupConfirmed();
    } catch (_) {
      if (_active) {
        state = state.copyWith(
            step: DeviceAddStep.credentials,
            busy: false,
            errorKey: 'device_add_connection_error');
      }
    }
  }

  Future<void> recheckRegistration() async {
    if (!_active || state.busy) return;
    state = state.copyWith(busy: true);
    final results = {...state.results};
    for (final entry in results.entries.toList()) {
      final result = entry.value;
      if (result.outcome != DeviceAddOutcome.registrationPending ||
          result.hardwareId == null) {
        continue;
      }
      try {
        final id = await _confirm(entry.key, result.hardwareId!);
        if (!_active) return;
        if (id != null) {
          results[entry.key] = DeviceAddResult(
              candidate: result.candidate,
              outcome: DeviceAddOutcome.registered,
              registeredId: id,
              hardwareId: result.hardwareId,
              wifiConnected: result.wifiConnected);
          _completed?.call();
        }
      } catch (_) {/* Read failure cannot turn into a re-pair. */}
    }
    if (!_active) return;
    state = state.copyWith(results: Map.unmodifiable(results), busy: false);
    await groupConfirmed();
  }

  Future<void> groupConfirmed() async {
    if (!_active || state.groupId != null) return;
    final ids = <PairTargetKind, String>{
      for (final e in state.results.entries)
        if (e.value.registeredId case final id?) e.key: id
    };
    if (ids.length != 2) return;
    state = state.copyWith(busy: true, groupError: false);
    try {
      final groupId = await _group(_account, Map.unmodifiable(ids));
      if (_active) {
        state =
            state.copyWith(groupId: groupId, busy: false, groupError: false);
      }
    } catch (_) {
      if (_active) state = state.copyWith(busy: false, groupError: true);
    }
  }

  Future<void> continueAdding() async {
    if (!_active || state.busy) return;
    state = state.copyWith(
        selected: const {}, step: DeviceAddStep.scan, networks: const []);
    await scan();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    unawaited(_scan.cancel());
    unawaited(_gateway.dispose());
    super.dispose();
  }
}
