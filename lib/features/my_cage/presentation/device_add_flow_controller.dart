import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/device_add_ble_adapter.dart';
import '../data/device_add_registration_repository.dart';
import '../data/known_device_store.dart';
import '../data/wifi_credentials_store.dart';
import '../domain/device_add_flow.dart';
import '../domain/pair_target_kind.dart';
import '../domain/redesign_management.dart';
import 'supabase_module_providers.dart';

final deviceAddAccountProvider = Provider<String?>(
    (ref) => ref.watch(currentUserProvider.select((u) => u?.id)));
final deviceAddGatewayFactoryProvider =
    Provider<DeviceAddGateway Function()>((ref) => DeviceAddBleAdapter.new);
/// 자동 묶기·완료 콜백은 `DeviceAddFlowRoute`의 안쪽 `ProviderScope`에서 바꿔
/// 끼운다. 그래서 둘 다 scope 대상(`dependencies`)으로 선언하고, 이를 읽는
/// [deviceAddFlowProvider]도 `dependencies`에 적는다 — 안 적으면 flow가 최상위
/// 컨테이너에 만들어져 아래 기본값(항상 실패)을 읽는다(2026-09-22 사고).
final deviceAddAutoGroupProvider = Provider<DeviceAddAutoGroup>(
    (ref) =>
        (account, ids) async => throw StateError('Atomic grouping unavailable'),
    dependencies: const []);
final knownDeviceStoreProvider =
    Provider<KnownDeviceStore>((ref) => const HiveKnownDeviceStore());
final deviceAddCompletedProvider =
    Provider<void Function()>((ref) => () {}, dependencies: const []);
/// 등록 확인(읽기 전용)·세션 계정 확인. 통합 테스트가 실제 Route·컨트롤러를
/// 그대로 두고 서버만 바꿔 끼울 수 있게 provider로 뺐다.
final deviceAddRegistrationProvider = Provider<DeviceAddRegistrationRepository>(
    (ref) => DeviceAddRegistrationRepository(ref.watch(supabaseClientProvider)));
final deviceAddSessionUserProvider = Provider<String? Function()>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  return () => auth.currentUser?.id;
});
final deviceAddFlowProvider = StateNotifierProvider.autoDispose
    .family<DeviceAddFlowController, DeviceAddState, Object>((ref, key) {
  final account = ref.watch(deviceAddAccountProvider);
  final sessionUser = ref.watch(deviceAddSessionUserProvider);
  final registration = ref.watch(deviceAddRegistrationProvider);
  final credentials = WifiCredentialsStore();
  final group = ref.watch(deviceAddAutoGroupProvider);
  final completed = ref.watch(deviceAddCompletedProvider);
  final gatewayFactory = ref.watch(deviceAddGatewayFactoryProvider);
  final freshToken = ref.watch(freshAccessTokenProvider);
  final known = ref.watch(knownDeviceStoreProvider);
  var active = true;
  ref.onDispose(() => active = false);
  return DeviceAddFlowController(
      gateway: gatewayFactory(),
      accountId: account ?? '',
      isCurrent: () =>
          active && account != null && sessionUser() == account,
      // 등록 직전에 갱신한 토큰 — 만료 토큰이면 기기의 /devices/pair가 401.
      token: () async => await freshToken() ?? '',
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
      completed: completed,
      // 기억한 카메라라도 이 계정에 행이 남아 있어야 Wi-Fi만 바꾼다.
      knownCamera: (candidate) async {
        final id = known.load(account!, candidate);
        if (id == null) return null;
        return await registration.ownedCamera(account, id) == null ? null : id;
      },
      // 목록 '이미 등록됨' — 기억한 행이 이 계정에 해제 없이 남아 있을 때만.
      registered: (candidate) async {
        final id = known.load(account!, candidate);
        if (id == null) return false;
        return candidate.kind == PairTargetKind.camera
            ? await registration.ownedCamera(account, id) != null
            : await registration.ownedDevice(account, id);
      },
      rememberCamera: (candidate, id) => known.save(account!, candidate, id),
      forgetCamera: (candidate) => known.forget(account!, candidate),
      cameraLastSeen: (id) async =>
          (await registration.ownedCamera(account!, id))?.lastSeen);
}, dependencies: [deviceAddAutoGroupProvider, deviceAddCompletedProvider]);

class DeviceAddFlowController extends StateNotifier<DeviceAddState> {
  DeviceAddFlowController(
      {required DeviceAddGateway gateway,
      required String accountId,
      required bool Function() isCurrent,
      required FutureOr<String> Function() token,
      required String Function(PairTargetKind) namePrefix,
      required Future<List<String>> Function() names,
      required Future<String?> Function(PairTargetKind, String) confirm,
      required Future<void> Function(String, String) saveCredentials,
      required Future<Map<String, String>> Function() readCredentials,
      required DeviceAddAutoGroup autoGroup,
      void Function()? completed,
      Future<String?> Function(DeviceAddCandidate)? knownCamera,
      Future<bool> Function(DeviceAddCandidate)? registered,
      Future<void> Function(DeviceAddCandidate, String)? rememberCamera,
      Future<void> Function(DeviceAddCandidate)? forgetCamera,
      Future<DateTime?> Function(String)? cameraLastSeen,
      this.reconnectPoll = const Duration(seconds: 5),
      this.reconnectTimeout = const Duration(seconds: 90)})
      : _known = knownCamera,
        _registered = registered,
        _rememberCamera = rememberCamera,
        _forgetCamera = forgetCamera,
        _lastSeen = cameraLastSeen,
        _gateway = gateway,
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
      if (!_active) return;
      state = state.copyWith(candidates: List.unmodifiable(rows));
      for (final candidate in rows) {
        if (_checked.add(candidate.physicalId)) {
          unawaited(_checkRegistered(candidate));
        }
      }
    }, onError: (Object _) {
      if (_active) {
        state = state.copyWith(busy: false, errorKey: 'device_add_scan_error');
      }
    });
  }
  final DeviceAddGateway _gateway;
  final String _account;
  final bool Function() _isCurrent;
  final FutureOr<String> Function() _token;
  final String Function(PairTargetKind) _namePrefix;
  final Future<List<String>> Function() _names;
  final Future<String?> Function(PairTargetKind, String) _confirm;
  final Future<void> Function(String, String) _save;
  final Future<Map<String, String>> Function() _read;
  final DeviceAddAutoGroup _group;
  final void Function()? _completed;

  @visibleForTesting
  DeviceAddAutoGroup get debugAutoGroup => _group;
  @visibleForTesting
  void Function()? get debugCompleted => _completed;

  /// 이 폰이 등록해 둔 카메라인지(BLE 주소 → cameras.id). 있으면 JWT 없이
  /// Wi-Fi만 바꾼다 — 카메라 펌웨어는 JWT를 받을 때마다 새 camera_id로
  /// 등록해 행이 늘어난다(2026-09-21).
  final Future<String?> Function(DeviceAddCandidate)? _known;
  final Future<bool> Function(DeviceAddCandidate)? _registered;

  /// 등록 여부를 이미 물어본 BLE 주소 — 스캔 갱신마다 다시 묻지 않는다.
  final Set<String> _checked = {};
  final Future<void> Function(DeviceAddCandidate, String)? _rememberCamera;
  final Future<void> Function(DeviceAddCandidate)? _forgetCamera;
  final Future<DateTime?> Function(String)? _lastSeen;

  /// 카메라는 Wi-Fi를 받으면 재부팅한 뒤 서버에 붙는다(~20초).
  final Duration reconnectPoll, reconnectTimeout;
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
        final existing = await _existingCamera(candidate);
        if (!_active) return;
        if (existing != null) {
          await _updateWifi(candidate, existing, ssid, password, remember);
          continue;
        }
        final prefix = _namePrefix(candidate.kind);
        final name = nextManagementName(prefix, names);
        names.add(name);
        final receipt = await _gateway.provision(candidate,
            ssid: ssid,
            password: password,
            name: name,
            jwt: await _token(),
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
            registeredName: name,
            issue: id != null ? null : receipt.issue,
            issueDetail: id != null ? null : receipt.issueDetail,
            outcome: id != null
                ? DeviceAddOutcome.registered
                : receipt.retrySafe
                    ? DeviceAddOutcome.wifiFailed
                    : DeviceAddOutcome.registrationPending);
        state = state.copyWith(
            results:
                Map.unmodifiable({...state.results, candidate.kind: result}));
        if (id != null) {
          await _remember(candidate, id);
          _completed?.call();
        }
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
              registeredName: result.registeredName,
              hardwareId: result.hardwareId,
              wifiConnected: result.wifiConnected);
          await _remember(result.candidate, id);
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
    // 새로 등록한 기기끼리만 묶는다. Wi-Fi만 바꾼 카메라는 이미 제 사육
    // 환경이 있을 수 있어 자동으로 옮기지 않는다.
    final ids = <PairTargetKind, String>{
      for (final e in state.results.entries)
        if (e.value.outcome == DeviceAddOutcome.registered)
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

  /// 등록한 기기를 기억한다. 카메라는 다음 연결을 Wi-Fi 변경으로, 사육장은
  /// 목록 '이미 등록됨' 표시에만 쓴다(등록을 마친 기기도 몇 분간 광고한다).
  Future<void> _remember(DeviceAddCandidate candidate, String id) async {
    if (_active) {
      state = state.copyWith(
          registered:
              Set.unmodifiable({...state.registered, candidate.physicalId}));
    }
    try {
      await _rememberCamera?.call(candidate, id);
    } catch (_) {/* 못 기억하면 다음에 한 번 더 등록될 뿐이다. */}
  }

  Future<void> _checkRegistered(DeviceAddCandidate candidate) async {
    final check = _registered;
    if (check == null) return;
    bool yes;
    try {
      yes = await check(candidate);
    } catch (_) {
      _checked.remove(candidate.physicalId); // 다음 스캔 때 다시 묻는다.
      return;
    }
    if (!yes || !_active) return;
    state = state.copyWith(
        registered:
            Set.unmodifiable({...state.registered, candidate.physicalId}));
  }

  Future<String?> _existingCamera(DeviceAddCandidate candidate) async {
    if (candidate.kind != PairTargetKind.camera) return null;
    try {
      return await _known?.call(candidate);
    } catch (_) {
      return null; // 판별 불가 → 지금까지처럼 등록한다.
    }
  }

  Future<void> _updateWifi(DeviceAddCandidate candidate, String id, String ssid,
      String password, bool remember) async {
    final receipt = await _gateway.provision(candidate,
        ssid: ssid,
        password: password,
        name: '',
        jwt: '',
        wifiOnly: true,
        isCurrent: () => _active,
        onWifiConnected: () async {
          if (_active && remember) {
            try {
              await _save(ssid, password);
            } catch (_) {/* optional */}
          }
        });
    if (!_active) return;
    // BLE 회신은 힌트일 뿐, 최종 판정은 서버 last_seen_at이다(2026-09-24):
    // 카메라는 Wi-Fi에 붙으면 재부팅하며 BLE를 끊어 WIFI_OK가 유실되기 쉬웠고,
    // 실제론 붙은 카메라를 '연결 실패'로 표시했다(사육장+카메라 동시 등록 사고).
    // 단 기기가 WIFI_FAIL로 실패를 확정했거나 CONNECT가 가기도 전에 끊겼으면
    // 서버 감시가 오히려 오판한다(옛 Wi-Fi 하트비트가 계속 온다) — 즉시 실패.
    // last_seen_at을 볼 수 없을 때도 예전처럼 즉시 실패.
    final lastSeen = _lastSeen;
    final probe = lastSeen != null && receipt.worthWatching;
    final result = receipt.wifiConnected || probe
        ? DeviceAddResult(
            candidate: candidate,
            outcome: DeviceAddOutcome.wifiUpdated,
            registeredId: id,
            wifiConnected: receipt.wifiConnected,
            reconnect: probe ? CameraReconnect.waiting : null)
        : DeviceAddResult(
            candidate: candidate, outcome: DeviceAddOutcome.wifiFailed);
    state = state.copyWith(
        results: Map.unmodifiable({...state.results, candidate.kind: result}));
    if (receipt.wifiConnected) _completed?.call();
    if (result.reconnect == CameraReconnect.waiting) {
      // 기준값은 영수증 '뒤'에 읽는다 — BLE 세션 중 옛 Wi-Fi로 보낸 하트비트가
      // 새 Wi-Fi 접속으로 읽히면 안 된다. 폰 시계와 서버 시계가 어긋나도
      // '기준값보다 새로운 last_seen_at'은 흔들리지 않는다. 기준값을 못 읽으면
      // 영수증 시각(폰 시계)으로 대신한다.
      final since = DateTime.now();
      DateTime? baseline;
      var baselineKnown = false;
      try {
        baseline = await lastSeen!(id);
        baselineKnown = true;
      } catch (_) {/* 아래 폴백 */}
      if (!_active) return;
      unawaited(_watchReconnect(candidate.kind, id,
          since: since, baseline: baseline, baselineKnown: baselineKnown));
    }
  }

  /// 재부팅한 카메라가 기존 행으로 다시 붙는지 last_seen_at으로 본다.
  /// [baselineKnown]이면 [baseline]보다 새로운 값만, 아니면 [since] 이후 값을 접속으로.
  Future<void> _watchReconnect(PairTargetKind kind, String id,
      {required DateTime since,
      required DateTime? baseline,
      required bool baselineKnown}) async {
    final lastSeen = _lastSeen;
    if (lastSeen == null) return;
    bool isNew(DateTime seen) => baselineKnown
        ? (baseline == null || seen.isAfter(baseline))
        : seen.isAfter(since);
    final deadline = DateTime.now().add(reconnectTimeout);
    while (true) {
      await Future<void>.delayed(reconnectPoll);
      if (!_active) return;
      final current = state.results[kind];
      if (current?.registeredId != id ||
          current?.reconnect != CameraReconnect.waiting) {
        return;
      }
      DateTime? seen;
      try {
        seen = await lastSeen(id);
      } catch (_) {/* 다음 주기에 다시 본다. */}
      if (!_active) return;
      final online = seen != null && isNew(seen);
      final expired = !DateTime.now().isBefore(deadline);
      if (!online && !expired) continue;
      final latest = state.results[kind];
      if (latest?.registeredId != id) return;
      state = state.copyWith(
          results: Map.unmodifiable({
        ...state.results,
        kind: latest!.withReconnect(
            online ? CameraReconnect.online : CameraReconnect.missing)
      }));
      // BLE 성공 없이 서버로만 확인된 경우 — 지금이 연결 완료 시점이다.
      if (online && !latest.wifiConnected) _completed?.call();
      return;
    }
  }

  /// 저장값이 지워진 카메라처럼 Wi-Fi 변경으로는 안 붙는 경우 — 기억을 지우고
  /// 다음 연결에서 새로 등록한다.
  Future<void> registerAsNew(PairTargetKind kind) async {
    final result = state.results[kind];
    if (!_active || state.busy || result == null) return;
    try {
      await _forgetCamera?.call(result.candidate);
    } catch (_) {/* 기억이 남으면 다시 Wi-Fi만 바꾸게 된다. */}
    if (!_active) return;
    final results = {...state.results}..remove(kind);
    state = state.copyWith(
        registered: Set.unmodifiable(
            {...state.registered}..remove(result.candidate.physicalId)),
        results: Map.unmodifiable(results),
        selected:
            Map.unmodifiable({...state.selected, kind: result.candidate}));
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
