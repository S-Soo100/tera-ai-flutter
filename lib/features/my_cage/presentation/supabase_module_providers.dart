import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/resilient_channel.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../wiki/data/care_info_repository.dart';
import '../data/supabase_module_control_repository.dart';
import '../domain/device.dart';
import '../domain/device_command.dart';
import '../domain/species_comfort.dart';
import '../domain/telemetry_bucket.dart';
import '../domain/telemetry_reading.dart';
import 'my_cage_providers.dart';

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
  // 계정 전환·로그인 시 재조회 (project_auth_provider_stale_pattern).
  // 없으면 게스트 상태에서 RLS가 무에러로 돌려준 빈 목록이 캐시돼, 로그인
  // 후에도 통계·제어가 "기기 없음"으로 남는다(2026-08-14 실기기 확인).
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(supabaseModuleControlRepositoryProvider).listDevices();
});

// ── 기기 등록용 access token ───────────────────────────────────────────────────

/// BLE로 기기에 넘길 access token. **등록 직전에 갱신**한다 — 기기가 이 토큰으로
/// `POST /devices/pair`를 호출하는데 만료 토큰이면 401이고 앱엔 알림이 없다
/// (요청서 2026-09-17 §1-3). 갱신 실패 시 아직 유효한 현재 토큰으로 대체한다.
final freshAccessTokenProvider = Provider<Future<String?> Function()>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  return () async {
    try {
      final res = await auth.refreshSession();
      final token = res.session?.accessToken;
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    final session = auth.currentSession;
    if (session == null || session.isExpired) return null;
    return session.accessToken;
  };
});

// ── 선택된 디바이스 ID (PR4: device 선택 UI에서 갱신) ─────────────────────────

/// null = 선택 없음(자동). 복수 device 선택 칩 탭 시 갱신.
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// ── 현재 디바이스 (selectedDeviceIdProvider 우선, fallback = list.first) ────────

final currentDeviceProvider = FutureProvider.autoDispose<Device?>((ref) async {
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
///
/// 구독이 조용히 죽는 경우를 앱이 스스로 복구한다(2026-09-24 S21+ 실측 — 폰
/// Wi-Fi를 껐다 켠 뒤 기기는 3초마다 DB에 쓰는데 앱만 40분간 못 받았다):
/// - 구독 오류·망 복귀·앱 복귀 → 채널 재생성, 재합류하면 최신값 재조회
/// - [telemetryStaleThreshold] 동안 값이 안 오면 REST로 최신값을 확인해
///   **서버엔 새 값이 있는데 못 받은 것**이면 그 값을 흘리고 채널을 다시 만든다.
///   서버도 새 값이 없으면(기기가 정말 조용함) 채널은 건드리지 않는다.
final telemetryStreamProvider = StreamProvider.autoDispose
    .family<TelemetryReading?, String>((ref, deviceId) {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(supabaseModuleControlRepositoryProvider);

  final controller = StreamController<TelemetryReading?>();
  TelemetryReading? last;
  late final SilenceProbe probe;

  void emit(TelemetryReading t) {
    if (controller.isClosed) return;
    last = t;
    probe.onEvent();
    controller.add(t);
  }

  /// REST 최신값. 받은 것보다 새로우면 흘리고 true.
  Future<bool> pullLatest() async {
    try {
      final t = await repo.latestTelemetry(deviceId);
      if (t == null) return false;
      final prev = last?.ts;
      final newer = prev == null || (t.ts != null && t.ts!.isAfter(prev));
      if (newer) emit(t);
      return newer;
    } catch (_) {
      return false; // 망 없음 등 — 다음 주기에 다시 본다
    }
  }

  final channel = bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'telemetry-$deviceId',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'telemetry',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'device_id',
        value: deviceId,
      ),
      callback: (payload) => emit(TelemetryReading.fromJson(payload.newRecord)),
    ),
    // 끊긴 사이 빠진 값 — 재합류하면 최신값부터 다시 맞춘다.
    onRejoined: () => unawaited(pullLatest()),
  );

  probe = SilenceProbe(
    interval: telemetryStaleThreshold,
    onSilent: () async {
      final hadMissed = last != null && await pullLatest();
      if (hadMissed && !controller.isClosed) {
        debugPrint('[realtime] telemetry-$deviceId missed INSERT — rebuild');
        unawaited(channel.restart('silent-but-server-has-new'));
      }
    },
  )..start();

  // 최신값 seed (에러는 무시 — 이후는 Realtime + 무소식 확인으로 유지)
  unawaited(pullLatest());

  ref.onDispose(() {
    probe.dispose();
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

/// 기기 1대의 연결 상태(`is_online`·`last_seen_at`).
///
/// 목록 스냅샷으로 시작해 `devices` UPDATE 실시간과 재합류 재조회로 갱신한다
/// (2026-09-25). 전엔 앱을 켤 때 읽은 목록 값만 봐서, 켤 때 꺼져 있던 사육장은
/// 복구돼도 재시작 전까지 "기기 연결이 끊겼어요"+제어 잠금이었다. 해제됐거나
/// 목록에 없으면 null.
final deviceLinkStatusProvider = StreamProvider.autoDispose
    .family<DeviceLinkStatus?, String>((ref, deviceId) {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(supabaseModuleControlRepositoryProvider);
  final listFuture = ref.watch(deviceListProvider.future);
  final controller = StreamController<DeviceLinkStatus?>();
  var live = false; // 실시간·재조회 값이 오면 목록 스냅샷으로 덮지 않는다.
  var emitted = false;
  DeviceLinkStatus? last;

  void emit(DeviceLinkStatus? s, {bool fromLive = true}) {
    if (controller.isClosed) return;
    if (!fromLive && live) return;
    if (fromLive) live = true;
    if (emitted && s == last) return; // 같은 값 재방출은 하위를 흔들기만 한다.
    emitted = true;
    last = s;
    controller.add(s);
  }

  unawaited(() async {
    try {
      final list = await listFuture;
      final device = list.where((d) => d.id == deviceId).firstOrNull;
      emit(device == null ? null : DeviceLinkStatus.of(device),
          fromLive: false);
    } catch (e, st) {
      if (!live && !controller.isClosed) controller.addError(e, st);
    }
  }());

  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'device-link-$deviceId',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'devices',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: deviceId,
      ),
      callback: (payload) {
        if (payload.newRecord['unlinked_at'] != null) {
          // 다른 폰에서 해제됐다 — 목록을 다시 읽어 홈에서 빠지게 한다.
          // 안 하면 "확인 중"에 갇힌 채 남는다.
          emit(null);
          ref.invalidate(deviceListProvider);
          return;
        }
        emit(DeviceLinkStatus.fromJson(payload.newRecord));
      },
    ),
    // 끊긴 사이의 온라인 변화를 놓쳤을 수 있다 — 서버 값으로 다시 맞춘다.
    onRejoined: () async {
      try {
        emit(await repo.fetchLinkStatus(deviceId));
      } catch (_) {/* 다음 재합류·UPDATE에서 다시 맞춘다 */}
    },
  );

  ref.onDispose(controller.close);
  return controller.stream;
});

/// 사육장 제어기 연결 상태 3값(2026-09-23). "모름"을 오프라인으로 그리면 앱을
/// 켜자마자 "기기 연결이 끊겼어요"가 보이고 카메라까지 고장으로 읽힌다.
enum ModuleLink { unknown, online, offline }

/// - `unknown`: 기기를 아직 못 받았거나(조회 중·실패) 값이 없음
/// - `online`: `device.is_online` **AND** telemetry 최신 — 제어 허용
/// - `offline`: 둘 중 하나라도 끊김
///
/// `is_online`은 **이 기기**의 실시간 값([deviceLinkStatusProvider])이다 — 전엔
/// 목록 첫 기기의 앱 시작 시점 스냅샷을 봐서, 사육장이 2대면 다른 기기 상태로
/// 판정했다(2026-09-25). `telemetryStale`는 3초 주기 telemetry watchdog이다.
/// 재조회 중에는 이전 값을 유지한다(`hasValue`) — `isLoading`으로 판정하면
/// 재조회마다 "확인 중"이 깜빡인다(2026-09-19 교훈).
final moduleLinkProvider =
    Provider.autoDispose.family<ModuleLink, String>((ref, deviceId) {
  final status = ref.watch(deviceLinkStatusProvider(deviceId)
      .select((s) => (s.hasValue, s.valueOrNull?.isOnline)));
  if (!status.$1) return ModuleLink.unknown;
  final snapshot = status.$2;
  if (snapshot == null) return ModuleLink.unknown;
  final isStale =
      ref.watch(telemetryStaleProvider(deviceId)).valueOrNull ?? false;
  return snapshot && !isStale ? ModuleLink.online : ModuleLink.offline;
});

/// 사육장 제어 가능 여부 = [moduleLinkProvider]가 `online`. 미확인도 차단한다
/// — AND 결합은 보수적(둘 다 살아 있어야 제어 허용)이라 "오프라인인데 제어됨"
/// (위음성)을 최소화한다. 반대 위양성(정상인데 잠깐 차단)은 재시도로 해소한다.
final moduleOnlineProvider = Provider.autoDispose.family<bool, String>(
    (ref, deviceId) =>
        ref.watch(moduleLinkProvider(deviceId)) == ModuleLink.online);

// ── 상대 시간 tick ──────────────────────────────────────────────────────────────

/// 1분 주기로 현재 시각을 방출. 오프라인 시 "마지막 업데이트 N분 전" 표시를
/// 실시간으로 늘리기 위해 사용한다. autoDispose라 화면이 구독할 때만 타이머가 돈다.
final nowTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

// ── 명령 상태 업데이트 Realtime 스트림 ─────────────────────────────────────────

/// commands 테이블 UPDATE를 수신. RLS가 본인 발행 명령만 노출.
final commandUpdatesProvider = StreamProvider.autoDispose<DeviceCommand>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<DeviceCommand>();

  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'commands-rt',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'commands',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(DeviceCommand.fromJson(payload.newRecord));
        }
      },
    ),
  );

  ref.onDispose(controller.close);

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

/// 현재 사육장 종에서 도출한 적정 안심존. device→enclosure→species→care_info 체인.
/// 종 미설정이거나 미지원 종이면 null(차트에 안심존 밴드 미표시).
final currentSpeciesComfortProvider =
    FutureProvider.autoDispose<SpeciesComfort?>((ref) async {
  final device = await ref.watch(currentDeviceProvider.future);
  final encId = device?.enclosureId;
  if (encId == null || encId.isEmpty) return null;
  final enclosure = await ref.watch(enclosureProvider(encId).future);
  final sid = speciesIdFromText(enclosure?.species);
  if (sid == null) return null;
  final care = await ref.watch(careInfoRepositoryProvider).getCareInfo(sid);
  return SpeciesComfort(
    speciesId: sid,
    speciesNameKo: care.speciesNameKo,
    tempMin: care.coolZone.min.toDouble(),
    tempMax: care.hotZone.max.toDouble(),
    humidMin: care.humidityMin.toDouble(),
    humidMax: care.humidityMax.toDouble(),
  );
});
