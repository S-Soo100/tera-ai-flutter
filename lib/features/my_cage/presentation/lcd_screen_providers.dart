import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/terra_rest_client.dart';
import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/device_health_repository.dart';
import '../data/lcd_quiet_store.dart';
import '../data/lcd_repository.dart';
import '../domain/device.dart';
import '../domain/lcd_photo_codec.dart';
import '../domain/lcd_screen_state.dart';
import 'lcd_photo_picker.dart';
import 'supabase_module_providers.dart';
import 'widgets/lcd_setting_tile.dart' show lcdTextAccountProvider;

/// 모듈 화면 설정(LCD 전원·꺼짐 예약·화면 보호기·사진) 상태와 명령 실행기
/// (2026-11-03, 기획 `docs/superpowers/specs/2026-11-03-lcd-screen-settings-design.md`
/// §12 > §11 > 본문).
///
/// - 진실: 기기 행(`devices.lcd_*`·`capabilities`)의 실시간 값. `GET /lcd`
///   스냅샷은 "불러왔다"는 표시와 사진 미리보기용이다(§11-1).
/// - 쓰기: REST 201 → 그 `commands` 행을 1회 읽고 구독 → [classifyLcdCommand]
///   (§11-2). 대기 중에는 목표 상태를 그린다.

// ── 상태 읽기 ─────────────────────────────────────────────────────────────────

/// 진입 시 `GET /devices/{id}/lcd` 한 번(화면을 나가면 버린다 — 미리보기 URL이
/// 1시간짜리라 캐시하지 않는다). 계정이 바뀌면 다시 읽는다.
final lcdSnapshotProvider = FutureProvider.autoDispose
    .family<LcdStateSnapshot, String>((ref, deviceId) {
  ref.watch(lcdTextAccountProvider);
  return ref.watch(lcdRepositoryProvider).getState(deviceId);
});

/// 진입 시 기기 행 재조회 — 목록 캐시의 `capabilities`가 오래됐을 수 있다
/// (OTA로 지원이 켜진 직후, §11-1). 해제됐거나 안 보이면 null.
final lcdLinkRefreshProvider = FutureProvider.autoDispose
    .family<DeviceLinkStatus?, String>((ref, deviceId) {
  ref.watch(lcdTextAccountProvider);
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .fetchLinkStatus(deviceId);
});

/// 기기 행에서 LCD에 쓰는 값만. 3초마다 오는 기기 행(생존 신호)이 바뀌어도
/// `==`가 같으면 하위가 다시 그려지지 않는다.
typedef LcdLinkValues = ({
  DeviceLcdScreen screen,
  LcdSupport support,
  bool lcdOverride,
});

LcdLinkValues _linkValuesOf(DeviceLinkStatus s) =>
    (screen: s.lcdScreen, support: s.lcdSupport, lcdOverride: s.lcdOverride);

LcdLinkValues? _selectLink(AsyncValue<DeviceLinkStatus?> s) {
  final v = s.valueOrNull;
  return v == null ? null : _linkValuesOf(v);
}

/// 실시간 구독([deviceLinkStatusProvider])과 진입 시 재조회([lcdLinkRefreshProvider])
/// 중 **나중에 도착한 값**. 실시간 값은 바뀔 때만 오므로(같은 값 재방출 없음)
/// 도착 순서가 곧 신선도 순서다.
final _lcdLinkProvider = NotifierProvider.autoDispose
    .family<_LcdLinkController, LcdLinkValues?, String>(_LcdLinkController.new);

class _LcdLinkController
    extends AutoDisposeFamilyNotifier<LcdLinkValues?, String> {
  @override
  LcdLinkValues? build(String deviceId) {
    ref.listen(deviceLinkStatusProvider(deviceId).select(_selectLink),
        (_, next) {
      if (next != null) state = next;
    });
    ref.listen(lcdLinkRefreshProvider(deviceId), (_, next) {
      final v = next.valueOrNull;
      if (v != null) state = _linkValuesOf(v);
    });
    return _selectLink(ref.read(deviceLinkStatusProvider(deviceId)));
  }
}

/// 설정 화면이 그리는 값.
class LcdScreenView {
  const LcdScreenView({
    required this.screen,
    required this.support,
    required this.lcdOverride,
    this.previewUrl,
    this.rawImageKey,
  });

  /// 서버가 기기 ACK로 확정한 값(전원·예약·보호기·사진·실제 화면 상태).
  /// 사진 실패(§12-2)를 앱이 기억하는 동안엔 사진을 비워서 그린다
  /// ([lcdPhotoLostProvider]) — 원래 key는 [rawImageKey].
  final DeviceLcdScreen screen;
  final LcdSupport support;

  /// 신 nano 펌웨어(`capabilities.lcd_override`) — §12-1.
  final bool lcdOverride;

  /// `GET /lcd`의 사진 미리보기(지원 기기만 읽는다).
  final String? previewUrl;

  /// 서버가 가진 `lcd_image_key` 그대로(사진 실패 기억으로 가리기 전).
  final String? rawImageKey;

  /// 전원 스위치에 그릴 확정값(§12-1 분기).
  bool get switchOn => screen.switchOn(lcdOverride: lcdOverride);

  /// 신 규칙으로 그리는가 — 능력이 있고 화면 상태 보고가 왔다(§12-1).
  bool get overrideRule => lcdOverride && screen.screenOn != null;

  @override
  bool operator ==(Object other) =>
      other is LcdScreenView &&
      other.screen == screen &&
      other.support == support &&
      other.lcdOverride == lcdOverride &&
      other.previewUrl == previewUrl &&
      other.rawImageKey == rawImageKey;

  @override
  int get hashCode =>
      Object.hash(screen, support, lcdOverride, previewUrl, rawImageKey);
}

/// 설정 화면 상태. 지원 기기는 `GET /lcd`까지 읽어야 data다 — 그 전엔 모든
/// 쓰기를 막는다(기본값으로 기존 설정을 덮지 않게, §11-1). 구 펌웨어·허브는
/// 쓸 일이 없어 기기 행만으로 그린다.
final lcdScreenViewProvider = Provider.autoDispose
    .family<AsyncValue<LcdScreenView>, String>((ref, deviceId) {
  var link = ref.watch(_lcdLinkProvider(deviceId));
  if (link == null) {
    final refresh = ref.watch(lcdLinkRefreshProvider(deviceId));
    final fresh = refresh.valueOrNull;
    if (fresh != null) {
      link = _linkValuesOf(fresh);
    } else if (refresh.isLoading) {
      // 재시도 중엔 이전 오류 대신 불러오는 모양.
      return const AsyncLoading<LcdScreenView>();
    } else if (refresh.hasError) {
      return AsyncError<LcdScreenView>(refresh.error!, refresh.stackTrace!);
    } else if (refresh.hasValue) {
      return AsyncError<LcdScreenView>(
          StateError('device $deviceId not found'), StackTrace.current);
    } else {
      return const AsyncLoading<LcdScreenView>();
    }
  }
  if (link.support != LcdSupport.supported) {
    return AsyncData(LcdScreenView(
        screen: link.screen,
        support: link.support,
        lcdOverride: link.lcdOverride));
  }
  final snapshot = ref.watch(lcdSnapshotProvider(deviceId));
  final snap = snapshot.valueOrNull;
  if (snap == null) {
    if (!snapshot.isLoading && snapshot.hasError) {
      return AsyncError<LcdScreenView>(snapshot.error!, snapshot.stackTrace!);
    }
    return const AsyncLoading<LcdScreenView>();
  }
  // 실시간 값이 진실이다 — 스냅샷은 첫 값(불러왔다는 표시)·미리보기용(§11-1).
  // 미리보기는 key별로 [lcdPreviewUrlProvider]가 다시 읽는다.
  final raw = link.screen;
  final lost = ref.watch(lcdPhotoLostProvider(deviceId));
  final hidden = lost != null && raw.imageKey == lost;
  return AsyncData(LcdScreenView(
      screen: hidden ? _withoutImage(raw) : raw,
      support: link.support,
      lcdOverride: link.lcdOverride,
      previewUrl: hidden ? null : snap.previewUrl,
      rawImageKey: raw.imageKey));
});

DeviceLcdScreen _withoutImage(DeviceLcdScreen s) => DeviceLcdScreen(
    power: s.power,
    quiet: s.quiet,
    saver: s.saver,
    updatedAt: s.updatedAt,
    screenOn: s.screenOn,
    overrideUntil: s.overrideUntil);

// ── 보호 사진 ─────────────────────────────────────────────────────────────────

/// 사진 실패(`dl_*`·`http_*`·`sha_mismatch`·`flash_write`, §12-2) 때의 서버
/// `lcd_image_key`. 그 key가 그대로인 동안 앱은 사진을 **없음**으로 그린다 —
/// 서버가 key를 비우기 전에도(이번 주 서버 수정 전) 기기와 맞게. key가 바뀌면
/// 자연히 풀리고, 사진 명령이 성공하면 지운다(같은 사진을 다시 올려 같은 key가
/// 돌아오는 경우). 계정이 바뀌면 버린다. 앱을 다시 켜면 잊는다(메모리).
final lcdPhotoLostProvider =
    NotifierProvider.family<LcdPhotoLostMemory, String?, String>(
        LcdPhotoLostMemory.new);

class LcdPhotoLostMemory extends FamilyNotifier<String?, String> {
  @override
  String? build(String deviceId) {
    ref.watch(lcdTextAccountProvider);
    return null;
  }

  /// 실패 시점의 key를 기억한다. 서버가 이미 비웠으면(null) 가릴 것이 없다 —
  /// 앞서 기억한 key는 그대로 둔다(같은 key로 또 실패한 경우).
  void mark(String? imageKey) {
    if (imageKey != null) state = imageKey;
  }

  void clear() => state = null;
}

/// 미리보기 key — (기기 행 id, 그 사진의 `lcd_image_key`).
typedef LcdPreviewKey = (String deviceId, String imageKey);

/// 사진 미리보기 URL(presigned 1시간, 캐시하지 않는다 — §3-4). 진입 때 읽은
/// `GET /lcd`의 key가 같으면 그 URL, `lcd_image_key`가 바뀌었으면 다시 읽는다.
/// 이미지 로드가 실패하면 화면이 [lcdSnapshotProvider]를 한 번 다시 읽힌다
/// (§8 만료).
final lcdPreviewUrlProvider =
    FutureProvider.autoDispose.family<String?, LcdPreviewKey>((ref, key) async {
  final (deviceId, imageKey) = key;
  final repo = ref.watch(lcdRepositoryProvider);
  final snap = await ref.watch(lcdSnapshotProvider(deviceId).future);
  if (snap.screen.imageKey == imageKey) return snap.previewUrl;
  return (await repo.getState(deviceId)).previewUrl;
});

/// "지금" — 꺼짐 예약 시간 안인지 판정할 때만 쓴다. 그릴 때·앱 복귀 때만
/// 다시 계산한다(경계 타이머 없음, §11-3). 복귀 때 화면이 invalidate한다.
final lcdNowProvider = Provider.autoDispose<DateTime>((ref) => clock.now());

// ── 꺼짐 예약 시간 ─────────────────────────────────────────────────────────────

final lcdQuietStoreProvider =
    Provider<LcdQuietStore>((ref) => const HiveLcdQuietStore());

/// 이 폰이 기억하는 꺼짐 예약 시간(기기별, D2). 서버 값이 있으면 그 값으로
/// 덮어쓴다(§11-3) — 그래서 예약을 끄면(서버 NULL) 직전 시간이 남는다.
final lcdQuietMemoryProvider = NotifierProvider.autoDispose
    .family<LcdQuietMemory, LcdQuietWindow?, String>(LcdQuietMemory.new);

class LcdQuietMemory
    extends AutoDisposeFamilyNotifier<LcdQuietWindow?, String> {
  @override
  LcdQuietWindow? build(String deviceId) {
    final account = ref.watch(lcdTextAccountProvider);
    final store = ref.watch(lcdQuietStoreProvider);
    LcdQuietWindow? serverOf(AsyncValue<LcdScreenView> v) =>
        v.valueOrNull?.screen.quiet;
    ref.listen(lcdScreenViewProvider(deviceId).select(serverOf), (_, next) {
      if (next != null) unawaited(remember(next));
    });
    final server = serverOf(ref.read(lcdScreenViewProvider(deviceId)));
    if (account == null) return server;
    if (server != null) {
      if (store.load(account, deviceId) != server) {
        unawaited(store.save(account, deviceId, server));
      }
      return server;
    }
    return store.load(account, deviceId);
  }

  /// 예약이 꺼진 채 시간을 고르면 여기만 바꾼다(기기로는 안 보낸다).
  Future<void> remember(LcdQuietWindow window) async {
    if (!window.isValid) return;
    state = window;
    final account = ref.read(lcdTextAccountProvider);
    if (account == null) return;
    await ref.read(lcdQuietStoreProvider).save(account, arg, window);
  }
}

/// 꺼짐 시간 줄에 그릴 시간 — 서버 → 폰 기억 → 20:00~08:00(§11-3).
final lcdQuietTimeProvider =
    Provider.autoDispose.family<LcdQuietWindow, String>((ref, deviceId) {
  final server = ref.watch(lcdScreenViewProvider(deviceId)
      .select((v) => v.valueOrNull?.screen.quiet));
  return server ??
      ref.watch(lcdQuietMemoryProvider(deviceId)) ??
      LcdQuietWindow.defaults;
});

// ── 명령 ─────────────────────────────────────────────────────────────────────

/// LCD 명령 종류 — 종류마다 실행기 하나(같은 종류는 한 번에 하나, §11-2).
enum LcdCommandKind { power, quiet, saver, image }

/// 실행기 키 — (기기 행 id, 종류).
typedef LcdCommandKey = (String deviceId, LcdCommandKind kind);

/// 보낼 명령과 그 목표 상태. 대기 중 화면은 이 목표를 그린다.
sealed class LcdCommandTarget {
  const LcdCommandTarget();

  LcdCommandKind get kind;

  /// 기기 확정값이 목표에 닿았나 — ok 뒤 스위치가 뒤로 튀지 않게 이때까지
  /// 목표를 유지한다(최대 [kLcdConfirmHold]).
  bool reachedBy(LcdScreenView view);
}

/// 화면 전원. 신 펌웨어는 `lcd_screen_on`, 구 펌웨어는 `lcd_power`로 판정
/// ([LcdScreenView.switchOn]).
final class LcdPowerTarget extends LcdCommandTarget {
  const LcdPowerTarget(this.on);
  final bool on;

  @override
  LcdCommandKind get kind => LcdCommandKind.power;

  @override
  bool reachedBy(LcdScreenView view) => view.switchOn == on;
}

/// 꺼짐 예약. [window]가 null이면 해제 — 해제가 성공하면 [previous]를 폰에
/// 기억한다(§11-3).
final class LcdQuietTarget extends LcdCommandTarget {
  const LcdQuietTarget.set(LcdQuietWindow this.window) : previous = null;
  const LcdQuietTarget.clear({this.previous}) : window = null;

  final LcdQuietWindow? window;
  final LcdQuietWindow? previous;

  bool get isClear => window == null;

  @override
  LcdCommandKind get kind => LcdCommandKind.quiet;

  @override
  bool reachedBy(LcdScreenView view) => view.screen.quiet == window;
}

/// 화면 보호기 — 5개 필드 전부(보호 사진 화면의 완료).
final class LcdSaverTarget extends LcdCommandTarget {
  const LcdSaverTarget(this.settings);
  final LcdSaverSettings settings;

  @override
  LcdCommandKind get kind => LcdCommandKind.saver;

  @override
  bool reachedBy(LcdScreenView view) => view.screen.saver == settings;
}

/// 보호 사진 올리기([bytes]) / 지우기([bytes] null). [previousKey]는 보낼 때의
/// 서버 `lcd_image_key`(가리기 전 — [LcdScreenView.rawImageKey]).
final class LcdImageTarget extends LcdCommandTarget {
  const LcdImageTarget.upload(List<int> this.bytes, {this.previousKey});
  const LcdImageTarget.delete({this.previousKey}) : bytes = null;

  final List<int>? bytes;
  final String? previousKey;

  bool get isDelete => bytes == null;

  @override
  LcdCommandKind get kind => LcdCommandKind.image;

  @override
  bool reachedBy(LcdScreenView view) => isDelete
      ? !view.screen.hasImage
      : view.screen.imageKey != null && view.screen.imageKey != previousKey;
}

/// 명령 하나의 끝. 문구는 [messageKeyFor]가 고른다(§11-2·§12-2).
enum LcdCommandResult {
  ok,

  /// `expired`·`device_offline` — 기기에 안 갔다.
  notDelivered,

  /// `no_ack`·`lost`·앱 쪽 한도 — 기기 응답을 못 받았다.
  noAck,

  /// `unknown_action`·400 `unsupported_firmware`.
  needsUpdate,

  /// 사진 다운로드·저장 실패 — 기기에 사진이 없다.
  photoLost,

  /// `busy` — 다른 사진을 받는 중.
  busy,

  /// `no_token` — 기기 재연결 필요.
  needsRepair,

  /// 422·`bad_request`·503·그 밖의 REST 실패·네트워크.
  sendFailed,

  /// 404/405 — 서버에 기능이 아직 없다(§8 서버 미배포).
  unavailable,

  /// 그 밖의 기기 거절.
  failed;

  bool get isOk => this == LcdCommandResult.ok;

  /// 안내 문구 키. ok는 null(조용히 끝낸다 — 스위치가 이미 목표에 있다).
  /// 사진이 기기에 남는 실패는 "기존 사진은 그대로예요"를 붙인다(§12-2).
  String? messageKeyFor(LcdCommandKind kind) {
    final photo = kind == LcdCommandKind.image;
    return switch (this) {
      ok => null,
      notDelivered => 'lcd_result_not_delivered',
      noAck => photo ? 'lcd_photo_no_ack' : 'lcd_result_no_ack',
      needsUpdate => 'lcd_result_needs_update',
      photoLost => 'lcd_photo_lost',
      busy => photo ? 'lcd_photo_busy' : 'lcd_result_busy',
      needsRepair => photo ? 'lcd_photo_no_token' : 'lcd_result_needs_repair',
      sendFailed => photo ? 'lcd_photo_send_failed' : 'lcd_result_send_failed',
      unavailable => 'lcd_result_unavailable',
      failed => 'lcd_result_failed',
    };
  }

  static LcdCommandResult ofOutcome(LcdCommandOutcome o) => switch (o) {
        LcdCommandOutcome.ok => ok,
        LcdCommandOutcome.notDelivered => notDelivered,
        LcdCommandOutcome.noAck => noAck,
        LcdCommandOutcome.needsUpdate => needsUpdate,
        LcdCommandOutcome.photoLost => photoLost,
        LcdCommandOutcome.photoBusy => busy,
        LcdCommandOutcome.needsRepair => needsRepair,
        LcdCommandOutcome.badRequest => sendFailed,
        LcdCommandOutcome.failed => failed,
        // 호출측이 대기는 거른다 — 혹시 오면 응답 없음으로 본다.
        LcdCommandOutcome.pending => noAck,
      };

  /// REST 실패(201을 못 받음). 원문은 보여주지 않는다.
  static LcdCommandResult ofRest(TerraRestException e) {
    if (e.isUnsupportedFirmware) return needsUpdate;
    if (e.statusCode == 404 || e.statusCode == 405) return unavailable;
    return sendFailed;
  }
}

/// 8초 무응답 — "응답이 늦어요"(대기는 유지, §11-2).
const kLcdCommandSlowAfter = Duration(seconds: 8);

/// 앱 쪽 마지막 한도. 서버가 30초에 `no_ack`/`expired`로 확정하므로 보통
/// 그 전에 끝난다 — Realtime이 죽어 결과를 못 받는 경우의 안전장치.
const kLcdCommandGiveUpAfter = Duration(seconds: 40);

/// ok 뒤 기기 확정값(`devices`)이 목표에 닿기를 기다리는 최대 시간(§11-2).
const kLcdConfirmHold = Duration(seconds: 3);

/// 실행기 상태.
class LcdCommandState {
  const LcdCommandState({
    this.target,
    this.slow = false,
    this.result,
    this.round = 0,
    this.uploadPreviewUrl,
  });

  /// 대기 중인 명령(목표). null이면 쉬는 중.
  final LcdCommandTarget? target;

  /// [kLcdCommandSlowAfter]가 지났다.
  final bool slow;

  /// 마지막 명령의 결과 — [round]가 바뀌어야 새 결과다.
  final LcdCommandResult? result;
  final int round;

  /// 사진 업로드 201의 서버 미리보기 — 끝난 뒤에도 남겨 새 미리보기 URL을
  /// 받는 동안 칸에 그린다(다음 명령을 보낼 때 지운다).
  final String? uploadPreviewUrl;

  bool get pending => target != null;
}

/// 명령 행(`commands`) 한 건 — 먼저 한 번 읽고(REST 응답 전에 끝났을 수 있다)
/// 그 행의 UPDATE를 구독한다(§11-2).
final lcdCommandRowProvider = StreamProvider.autoDispose
    .family<RebootCommandState?, String>((ref, commandId) {
  final repo = ref.watch(deviceHealthRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<RebootCommandState?>();

  Future<void> reload() async {
    try {
      final row = await repo.fetchCommand(commandId);
      if (!controller.isClosed && row != null) controller.add(row);
    } catch (_) {/* Realtime·앱 쪽 한도가 남는다. */}
  }

  unawaited(reload());
  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'lcd-command-$commandId',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'commands',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'id', value: commandId),
      callback: (payload) {
        if (!controller.isClosed) {
          controller
              .add(DeviceHealthRepository.commandStateOf(payload.newRecord));
        }
      },
    ),
    onRejoined: () => unawaited(reload()),
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

/// LCD 명령 실행기 — 종류마다 하나. 보내기 → 명령 행 → 결과 → (ok면) 기기
/// 확정값이 목표에 닿을 때까지 최대 3초 목표 유지(§11-2).
///
/// 실패하면 목표를 지워 스위치가 원위치로 돌아가고, 화면이 [LcdCommandState.result]
/// 로 안내한다(`ControlFeedback`). 화면을 나가면 버린다 — 단 **사진 명령은
/// 진행 중 keepAlive**(§11-5, `rebootProvider` 방식): 보호 사진 화면을 나가도
/// 업로드·기기 대기가 끝까지 가고, 결과는 `run(onResult:)`로 화면 밖에서도
/// 알린다. 끝나면 놓는다.
final lcdCommandProvider = NotifierProvider.autoDispose
    .family<LcdCommandController, LcdCommandState, LcdCommandKey>(
        LcdCommandController.new);

class LcdCommandController
    extends AutoDisposeFamilyNotifier<LcdCommandState, LcdCommandKey> {
  int _gen = 0;
  bool _disposed = false;
  Timer? _slow;
  Timer? _giveUp;
  Timer? _hold;
  ProviderSubscription<AsyncValue<RebootCommandState?>>? _row;
  ProviderSubscription<AsyncValue<LcdScreenView>>? _view;

  /// 사진 명령 진행 중 — 화면 없이도 살아 있게(§11-5).
  KeepAliveLink? _alive;

  /// 사진 명령 진행 중 기기 상태를 붙잡아 둔다 — 화면이 없을 때도 실패 시점의
  /// 서버 key를 알아야 한다([lcdPhotoLostProvider]).
  ProviderSubscription<AsyncValue<LcdScreenView>>? _viewHold;

  /// 이번 명령의 결과를 받을 곳(화면 밖 안내).
  void Function(LcdCommandResult result)? _onResult;

  String get _deviceId => arg.$1;

  @override
  LcdCommandState build(LcdCommandKey key) {
    ref.onDispose(() {
      _disposed = true;
      _stopWatching();
      _viewHold?.close();
      _viewHold = null;
    });
    return const LcdCommandState();
  }

  void _stopWatching() {
    _slow?.cancel();
    _giveUp?.cancel();
    _hold?.cancel();
    _row?.close();
    _row = null;
    _view?.close();
    _view = null;
  }

  bool _current(int gen) => !_disposed && gen == _gen;

  /// [target]을 보낸다. 이미 대기 중이면 무시하고 false. 서버가 받았으면(201)
  /// true — 결과는 [LcdCommandState]로 온다. [onResult]는 끝날 때 한 번
  /// 불린다(화면이 사라진 뒤에도 — 사진 명령은 이걸로 안내한다).
  Future<bool> run(LcdCommandTarget target,
      {void Function(LcdCommandResult result)? onResult}) async {
    assert(target.kind == arg.$2, 'target kind mismatch');
    if (_disposed || state.pending) return false;
    final gen = ++_gen;
    _onResult = onResult;
    if (target is LcdImageTarget) {
      _alive ??= ref.keepAlive();
      _viewHold ??= ref.listen(lcdScreenViewProvider(_deviceId), (_, __) {});
    }
    state = LcdCommandState(
        target: target, result: state.result, round: state.round);
    final String commandId;
    try {
      commandId = await _send(target, gen);
    } on TerraRestException catch (e) {
      _finish(gen, LcdCommandResult.ofRest(e));
      return false;
    } catch (_) {
      _finish(gen, LcdCommandResult.sendFailed);
      return false;
    }
    if (!_current(gen)) return true;
    _slow = Timer(kLcdCommandSlowAfter, () {
      if (_current(gen) && state.pending && !state.slow) {
        state = LcdCommandState(
            target: state.target,
            slow: true,
            result: state.result,
            round: state.round,
            uploadPreviewUrl: state.uploadPreviewUrl);
      }
    });
    _giveUp = Timer(
        kLcdCommandGiveUpAfter, () => _finish(gen, LcdCommandResult.noAck));
    _row = ref.listen(lcdCommandRowProvider(commandId), (_, next) {
      final row = next.valueOrNull;
      if (row == null || !_current(gen)) return;
      final outcome = classifyLcdCommand(row.status, row.result);
      if (outcome.isPending) return;
      if (outcome == LcdCommandOutcome.ok) {
        _confirm(gen, target);
      } else {
        _finish(gen, LcdCommandResult.ofOutcome(outcome));
      }
    }, fireImmediately: true);
    return true;
  }

  Future<String> _send(LcdCommandTarget target, int gen) async {
    final repo = ref.read(lcdRepositoryProvider);
    final id = _deviceId;
    switch (target) {
      case LcdPowerTarget(:final on):
        return repo.setPower(id, on);
      case LcdQuietTarget(:final window):
        return window == null ? repo.clearQuiet(id) : repo.setQuiet(id, window);
      case LcdSaverTarget(:final settings):
        return repo.setSaver(id, settings);
      case LcdImageTarget(:final bytes):
        if (bytes == null) return repo.deleteImage(id);
        final upload = await repo.uploadImage(id, bytes);
        if (_current(gen)) {
          state = LcdCommandState(
              target: state.target,
              slow: state.slow,
              result: state.result,
              round: state.round,
              uploadPreviewUrl: upload.previewUrl);
        }
        return upload.commandId;
    }
  }

  /// ok — 기기 확정값이 목표에 닿을 때까지(최대 [kLcdConfirmHold]) 목표 유지.
  void _confirm(int gen, LcdCommandTarget target) {
    _slow?.cancel();
    _giveUp?.cancel();
    _row?.close();
    _row = null;
    bool reached(AsyncValue<LcdScreenView> v) {
      final view = v.valueOrNull;
      return view != null && target.reachedBy(view);
    }

    if (reached(ref.read(lcdScreenViewProvider(_deviceId)))) {
      _finish(gen, LcdCommandResult.ok);
      return;
    }
    _hold = Timer(kLcdConfirmHold, () => _finish(gen, LcdCommandResult.ok));
    _view = ref.listen(lcdScreenViewProvider(_deviceId), (_, next) {
      if (reached(next)) _finish(gen, LcdCommandResult.ok);
    });
  }

  void _finish(int gen, LcdCommandResult result) {
    if (!_current(gen) || !state.pending) return;
    final target = state.target;
    _stopWatching();
    if (result.isOk &&
        target is LcdQuietTarget &&
        target.isClear &&
        target.previous != null) {
      unawaited(_rememberQuiet(target.previous!));
    }
    if (target is LcdImageTarget) _settlePhoto(target, result);
    state = LcdCommandState(
        result: result,
        round: state.round + 1,
        uploadPreviewUrl: state.uploadPreviewUrl);
    final onResult = _onResult;
    _onResult = null;
    onResult?.call(result);
    // 결과를 들을 화면이 있으면 그쪽이 잡고 있다 — 없으면 여기서 사라진다.
    _viewHold?.close();
    _viewHold = null;
    _alive?.close();
    _alive = null;
  }

  /// 사진 결과를 기억에 반영(§12-2). 실패로 기기에 사진이 없으면 지금 서버
  /// key를 가리고, 성공하면 앞선 실패 기억을 지운다.
  void _settlePhoto(LcdImageTarget target, LcdCommandResult result) {
    final memory = ref.read(lcdPhotoLostProvider(_deviceId).notifier);
    if (result.isOk) {
      memory.clear();
    } else if (result == LcdCommandResult.photoLost) {
      memory.mark(
          _viewHold?.read().valueOrNull?.rawImageKey ?? target.previousKey);
    }
  }

  /// 예약 해제 성공 — 직전 시간을 폰에 기억하고 시간 줄을 다시 읽힌다(§11-3).
  Future<void> _rememberQuiet(LcdQuietWindow previous) async {
    final account = ref.read(lcdTextAccountProvider);
    if (account == null) return;
    final store = ref.read(lcdQuietStoreProvider);
    try {
      await store.save(account, _deviceId, previous);
    } catch (_) {
      return; // 기억 실패 — 다음엔 기본값으로 보일 뿐이다.
    }
    if (!_disposed) ref.invalidate(lcdQuietMemoryProvider(_deviceId));
  }
}

// ── 꺼짐 시간 화면 초안 ────────────────────────────────────────────────────────

/// 화면 꺼짐 시간 화면에서 고치는 중인 시작·종료. 처음 값은 들어올 때의 시간
/// (서버 → 폰 기억 → 기본값)이고, 이후 들어오는 실시간 값으로 덮지 않는다.
class LcdQuietDraftState {
  const LcdQuietDraftState(
      {required this.initial, required this.start, required this.end});

  factory LcdQuietDraftState.of(LcdQuietWindow initial) => LcdQuietDraftState(
      initial: initial, start: initial.startAmPm, end: initial.endAmPm);

  final LcdQuietWindow initial;
  final LcdAmPmTime start;
  final LcdAmPmTime end;

  LcdQuietWindow get window => LcdQuietWindow.fromAmPm(start, end);

  /// 완료 활성 = 시작≠종료 AND 바뀜(§3-3).
  bool get canSubmit => window.isValid && window != initial;

  LcdQuietDraftState _with({LcdAmPmTime? start, LcdAmPmTime? end}) =>
      LcdQuietDraftState(
          initial: initial, start: start ?? this.start, end: end ?? this.end);
}

final lcdQuietDraftProvider = NotifierProvider.autoDispose
    .family<LcdQuietDraft, LcdQuietDraftState, String>(LcdQuietDraft.new);

class LcdQuietDraft
    extends AutoDisposeFamilyNotifier<LcdQuietDraftState, String> {
  @override
  LcdQuietDraftState build(String deviceId) {
    final pending =
        ref.read(lcdCommandProvider((deviceId, LcdCommandKind.quiet))).target;
    final LcdQuietWindow resolved = ref.read(lcdQuietTimeProvider(deviceId));
    final initial =
        (pending is LcdQuietTarget ? pending.window : null) ?? resolved;
    return LcdQuietDraftState.of(initial);
  }

  LcdAmPmTime _of(bool isStart) => isStart ? state.start : state.end;

  void _set(bool isStart, LcdAmPmTime t) =>
      state = isStart ? state._with(start: t) : state._with(end: t);

  /// 오전/오후 — 독립 토글.
  void setPm(bool isStart, bool pm) => _set(isStart, _of(isStart).withPm(pm));

  /// 시 1~12 순환(오전/오후 안 바뀜).
  void stepHour(bool isStart, int direction) =>
      _set(isStart, _of(isStart).stepHour(direction));

  /// 분 10분 단위 순환(칸 밖 분은 처음 누를 때 가까운 10분).
  void stepMinute(bool isStart, int direction) =>
      _set(isStart, _of(isStart).stepMinute(direction));
}

// ── 화면 보호 사진 화면 초안 ───────────────────────────────────────────────────

/// 보호 사진 화면에서 고치는 중인 보호기 켜짐·사진 노출·온습도 표시 시간
/// (§11-4). 기준선은 들어올 때의 값(보호기 명령 대기 중이면 그 목표)이고,
/// 이후 들어오는 실시간 값으로 덮지 않는다. 저장 안 한 변경은 화면을 나가면
/// 버린다(autoDispose).
class LcdSaverDraftState {
  const LcdSaverDraftState({
    required this.initial,
    required this.enabled,
    required this.imageSec,
    required this.infoSec,
  });

  /// 아직 불러오지 못함 — 편집·완료를 막는다(§11-1).
  static const unloaded = LcdSaverDraftState(
      initial: null, enabled: false, imageSec: 0, infoSec: 0);

  factory LcdSaverDraftState.of(LcdSaverSettings initial) => LcdSaverDraftState(
      initial: initial,
      enabled: initial.enabled,
      imageSec: initial.imageSec,
      infoSec: initial.infoSec);

  /// 기준선. null이면 불러오는 중.
  final LcdSaverSettings? initial;
  final bool enabled;

  /// 칸에 안 맞는 서버값(20초 등)은 그대로 들고 있다가, stepper를 처음 누를
  /// 때 칸으로 맞춘다([LcdStepper.next]).
  final int imageSec;
  final int infoSec;

  bool get loaded => initial != null;

  bool get enabledChanged => loaded && enabled != initial!.enabled;
  bool get imageSecChanged => loaded && imageSec != initial!.imageSec;
  bool get infoSecChanged => loaded && infoSec != initial!.infoSec;

  /// 완료를 켤 '바뀜'.
  bool get changed => enabledChanged || imageSecChanged || infoSecChanged;

  /// 보낼 5개 필드. 고치지 않은 필드는 **지금의 서버값**([server]) 그대로 —
  /// 스위치만 바꿨으면 시간은 서버값(§11-4), `mode`·`show_offline_icon`은
  /// 언제나 서버값(없으면 rotate·true, D6·D7).
  LcdSaverSettings toSettings(LcdSaverSettings server) => server.copyWith(
        enabled: enabledChanged ? enabled : null,
        imageSec: imageSecChanged ? imageSec : null,
        infoSec: infoSecChanged ? infoSec : null,
      );

  LcdSaverDraftState _with({bool? enabled, int? imageSec, int? infoSec}) =>
      LcdSaverDraftState(
          initial: initial,
          enabled: enabled ?? this.enabled,
          imageSec: imageSec ?? this.imageSec,
          infoSec: infoSec ?? this.infoSec);
}

/// 보호기 시간 칸 종류.
enum LcdSaverTime { image, info }

final lcdSaverDraftProvider = NotifierProvider.autoDispose
    .family<LcdSaverDraft, LcdSaverDraftState, String>(LcdSaverDraft.new);

class LcdSaverDraft
    extends AutoDisposeFamilyNotifier<LcdSaverDraftState, String> {
  @override
  LcdSaverDraftState build(String deviceId) {
    final saverKey = (deviceId, LcdCommandKind.saver);
    // 들어올 때 못 불러왔으면 처음 불러온 값을 기준선으로.
    ref.listen(lcdScreenViewProvider(deviceId), (_, next) {
      if (!state.loaded && next.hasValue) _rebase();
    });
    // 대기 중에 들어왔으면(편집 잠금) 끝난 뒤 서버값으로 다시 잡는다 — 손대지
    // 않았을 때만.
    ref.listen(lcdCommandProvider(saverKey), (prev, next) {
      if ((prev?.pending ?? false) && !next.pending && !state.changed) {
        _rebase();
      }
    });
    return _baseline() ?? LcdSaverDraftState.unloaded;
  }

  LcdSaverDraftState? _baseline() {
    final view = ref.read(lcdScreenViewProvider(arg)).valueOrNull;
    if (view == null || view.support != LcdSupport.supported) return null;
    final pending =
        ref.read(lcdCommandProvider((arg, LcdCommandKind.saver))).target;
    return LcdSaverDraftState.of(pending is LcdSaverTarget
        ? pending.settings
        : view.screen.saverOrDefault);
  }

  void _rebase() {
    final next = _baseline();
    if (next != null) state = next;
  }

  void setEnabled(bool value) {
    if (state.loaded) state = state._with(enabled: value);
  }

  /// +1/−1. 칸 밖 값은 처음 누를 때 칸으로 맞추기만 한다.
  void step(LcdSaverTime which, int direction) {
    if (!state.loaded) return;
    state = switch (which) {
      LcdSaverTime.image => state._with(
          imageSec: kLcdImageSecStepper.next(state.imageSec, direction)),
      LcdSaverTime.info =>
        state._with(infoSec: kLcdInfoSecStepper.next(state.infoSec, direction)),
    };
  }
}

// ── 사진 고르기 ───────────────────────────────────────────────────────────────

/// 사진 한 장을 고르고 잘라 업로드용 JPEG로 만든다. 테스트는 이걸 바꾼다.
typedef LcdPhotoPicker = Future<LcdPhotoPick> Function(BuildContext context);

final lcdPhotoPickerProvider = Provider<LcdPhotoPicker>((ref) => pickLcdPhoto);
