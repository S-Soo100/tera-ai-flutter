import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/supabase_module_control_repository.dart';
import '../domain/device.dart';
import '../domain/device_command.dart';
import '../domain/device_targets.dart';
import '../domain/telemetry_bucket.dart';
import '../domain/telemetry_reading.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

final supabaseModuleControlRepositoryProvider =
    Provider<SupabaseModuleControlRepository>((ref) {
  return SupabaseModuleControlRepository(
    supabase: ref.watch(supabaseClientProvider),
  );
});

// ── 디바이스 목록 ───────────────────────────────────────────────────────────────

final deviceListProvider =
    FutureProvider.autoDispose<List<Device>>((ref) async {
  return ref.watch(supabaseModuleControlRepositoryProvider).listDevices();
});

// ── 선택된 디바이스 ID (PR4: device 선택 UI에서 갱신) ─────────────────────────

/// null = 선택 없음(자동). 복수 device 선택 칩 탭 시 갱신.
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// ── 현재 디바이스 (selectedDeviceIdProvider 우선, fallback = list.first) ────────

final currentDeviceProvider =
    FutureProvider.autoDispose<Device?>((ref) async {
  final list = await ref.watch(deviceListProvider.future);
  if (list.isEmpty) return null;
  final selectedId = ref.watch(selectedDeviceIdProvider);
  if (selectedId != null) {
    final matched = list.where((d) => d.id == selectedId).firstOrNull;
    if (matched != null) return matched;
  }
  return list.first;
});

// ── 텔레메트리 Realtime 스트림 ──────────────────────────────────────────────────

/// `deviceId` family: 해당 디바이스의 telemetry INSERT를 실시간으로 수신.
/// 진입 시 latestTelemetry()로 시드하고, 이후 INSERT 이벤트로 갱신.
final telemetryStreamProvider = StreamProvider.autoDispose
    .family<TelemetryReading?, String>((ref, deviceId) {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(supabaseModuleControlRepositoryProvider);

  final controller = StreamController<TelemetryReading?>();

  // 최신값 seed (에러는 무시 — 스트림은 Realtime으로만 유지)
  repo.latestTelemetry(deviceId).then((t) {
    if (!controller.isClosed && t != null) controller.add(t);
  }).catchError((_) {});

  final channel = supabase.channel('telemetry-$deviceId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'telemetry',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'device_id',
          value: deviceId,
        ),
        callback: (payload) {
          if (!controller.isClosed) {
            controller.add(TelemetryReading.fromJson(payload.newRecord));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    // ignore: discarded_futures
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ── 텔레메트리 최신성 watchdog ──────────────────────────────────────────────────

/// 연결 끊김 판정 임계값. telemetry 3초 주기(terra-server 계약)의 4배 —
/// 일시적 지터는 흡수하고 실제 끊김만 감지한다.
const telemetryStaleThreshold = Duration(seconds: 12);

/// telemetry 최신성 감시자.
///
/// [telemetryStreamProvider]가 새 값을 방출할 때마다 이 provider가 재실행되어
/// watchdog 타이머를 리셋한다. [telemetryStaleThreshold] 동안 새 telemetry가
/// 없으면 `true`(stale = 연결 끊김)를 방출한다.
///
/// Supabase Realtime 스트림은 끊겨도 에러를 내지 않고 조용히 멈추므로
/// `hasError`로는 오프라인을 감지할 수 없다. 이 watchdog이 그 공백을 메운다.
final telemetryStaleProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, deviceId) {
  final telemetryAsync = ref.watch(telemetryStreamProvider(deviceId));
  final hasFresh = telemetryAsync.hasValue && telemetryAsync.value != null;

  final controller = StreamController<bool>();
  // 값이 막 도착했거나 아직 로딩 중이면 우선 not-stale.
  controller.add(false);

  Timer? timer;
  if (hasFresh) {
    timer = Timer(telemetryStaleThreshold, () {
      if (!controller.isClosed) controller.add(true);
    });
  }

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// 사육장 제어 가능 여부 = `device.is_online` 스냅샷 **AND** telemetry 최신성.
/// 둘 중 하나라도 끊기면 `false`(오프라인). 연결 끊김 시 제어 차단에 사용한다.
///
/// - `device.is_online`: 진입 시점 스냅샷(devices realtime 미구독) — 초기 판정.
/// - `telemetryStale`: 3초 주기 telemetry 기반 실시간 watchdog — 진입 후 끊김 감지.
///
/// AND 결합은 보수적(둘 다 살아 있어야 제어 허용)이라 "오프라인인데 제어됨"
/// (위음성)을 최소화한다. 반대 위양성(정상인데 차단)은 재시도로 해소한다.
final moduleOnlineProvider =
    Provider.autoDispose.family<bool, String>((ref, deviceId) {
  final device = ref.watch(currentDeviceProvider).valueOrNull;
  final isOnlineSnapshot = device?.isOnline ?? false;
  final isStale =
      ref.watch(telemetryStaleProvider(deviceId)).valueOrNull ?? false;
  return isOnlineSnapshot && !isStale;
});

// ── 상대 시간 tick ──────────────────────────────────────────────────────────────

/// 1분 주기로 현재 시각을 방출. 오프라인 시 "마지막 업데이트 N분 전" 표시를
/// 실시간으로 늘리기 위해 사용한다. autoDispose라 화면이 구독할 때만 타이머가 돈다.
final nowTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

// ── 명령 상태 업데이트 Realtime 스트림 ─────────────────────────────────────────

/// commands 테이블 UPDATE를 수신. RLS가 본인 발행 명령만 노출.
final commandUpdatesProvider =
    StreamProvider.autoDispose<DeviceCommand>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<DeviceCommand>();

  final channel = supabase.channel('commands-rt');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'commands',
        callback: (payload) {
          if (!controller.isClosed) {
            controller.add(DeviceCommand.fromJson(payload.newRecord));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    // ignore: discarded_futures
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ── 명령 발행 Notifier ─────────────────────────────────────────────────────────

class ModuleCommandSender extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  Future<DeviceCommand> send(
    String deviceId,
    CommandAction action, {
    Map<String, dynamic>? payload,
    int? ttlSec,
  }) {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다');
    return ref.read(supabaseModuleControlRepositoryProvider).sendCommand(
          deviceId: deviceId,
          action: action,
          payload: payload,
          ttlSec: ttlSec,
        );
  }
}

final moduleCommandSenderProvider =
    AutoDisposeNotifierProvider<ModuleCommandSender, void>(
  ModuleCommandSender.new,
);

// ── 텔레메트리 히스토리 (telemetry_30m, 장기 추이 그래프) ───────────────────────

/// 추이 그래프 조회 기간. 각 값은 조회 span과 세그먼트 라벨 키를 가진다.
enum TelemetryRange {
  h24(Duration(hours: 24), 'telemetry_range_24h'),
  d7(Duration(days: 7), 'telemetry_range_7d'),
  d30(Duration(days: 30), 'telemetry_range_30d');

  const TelemetryRange(this.span, this.labelKey);

  final Duration span;
  final String labelKey;
}

/// 선택된 추이 기간. 세그먼트 셀렉터 탭 시 갱신. 기본 7일.
final telemetryRangeProvider =
    StateProvider.autoDispose<TelemetryRange>((ref) => TelemetryRange.d7);

/// [deviceId]의 telemetry_30m 히스토리. 선택 기간만큼 조회(range 변경 시 재조회).
final telemetryHistoryProvider = FutureProvider.autoDispose
    .family<List<TelemetryBucket>, String>((ref, deviceId) {
  final from =
      DateTime.now().toUtc().subtract(ref.watch(telemetryRangeProvider).span);
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, from);
});

/// [deviceId]의 목표 온습도 범위. device_settings 없으면 null.
final deviceTargetsProvider =
    FutureProvider.autoDispose.family<DeviceTargets?, String>(
  (ref, deviceId) => ref
      .watch(supabaseModuleControlRepositoryProvider)
      .deviceTargets(deviceId),
);
