import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/terra_rest_client.dart';
import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/device_health_repository.dart';
import '../domain/pair_target_kind.dart';
import '../domain/sys_health.dart';
import 'my_cage_providers.dart';

/// 기기 한 대의 heartbeat 값(재시작 판정·Wi-Fi 약함) — 카메라·사육장 공통.
///
/// 목록 provider(`camerasProvider`·`deviceListProvider`)에 넣지 않는다 — 카메라
/// 목록은 생존 신호만 바뀐 갱신을 일부러 버리고(홈 깜빡임), 사육장은 3초마다
/// 바뀐다. 상세를 보는 동안만(autoDispose) 그 행의 UPDATE를 따로 구독한다.
/// 첫 값은 직결 조회(카메라 REST는 `clip_stats`가 빠져 있다), 재합류하면 다시
/// 읽는다. 읽기 실패는 "없음"(안내가 안 뜰 뿐).
final sysHealthProvider =
    StreamProvider.autoDispose.family<SysHealth, SysTarget>((ref, target) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  final (kind, id) = target;
  final camera = kind == PairTargetKind.camera;
  final cameras = ref.watch(cameraRepositoryProvider);
  final devices = ref.watch(deviceHealthRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<SysHealth>();

  Future<void> reload() async {
    try {
      final health = camera
          ? await cameras.fetchHealth(id)
          : await devices.fetchHealth(id);
      if (!controller.isClosed) controller.add(health);
    } catch (_) {
      if (!controller.isClosed) controller.add(SysHealth.empty);
    }
  }

  unawaited(reload());
  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'sys-health-${kind.name}-$id',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: camera ? 'cameras' : 'devices',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'id', value: id),
      callback: (payload) {
        if (controller.isClosed) return;
        controller.add(camera
            ? SysHealth.fromCameraRow(payload.newRecord)
            : SysHealth.fromDeviceRow(payload.newRecord));
      },
    ),
    onRejoined: () => unawaited(reload()),
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

/// 사육장 재시작 명령 한 건의 상태(`commands` 행). 먼저 한 번 읽고 — REST 응답
/// 전에 이미 acked됐을 수 있다 — 그 행의 UPDATE를 구독한다.
final rebootCommandProvider = StreamProvider.autoDispose
    .family<RebootCommandState?, String>((ref, commandId) {
  final repo = ref.watch(deviceHealthRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<RebootCommandState?>();

  Future<void> reload() async {
    try {
      final state = await repo.fetchCommand(commandId);
      if (!controller.isClosed && state != null) controller.add(state);
    } catch (_) {/* Realtime·2분 한도가 남는다. */}
  }

  unawaited(reload());
  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'reboot-command-$commandId',
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

/// 재시작 요청을 보낸 결과 — 화면이 안내를 고른다.
enum RebootRequest { published, notPublished, notFound, failed }

/// 재시작 뒤 결과.
/// [done]: 완료 신호. [timedOut]: 2분 무소식(전원 재연결 안내).
/// 사육장만(명령 결과가 온다): [noAck] 기기가 명령을 못 받음, [unsupported]
/// `unknown_action`(펌웨어 업데이트 필요), [failed] 그 밖의 `result`.
enum RebootOutcome { done, timedOut, noAck, unsupported, failed }

class RebootState {
  const RebootState(
      {this.sending = false,
      this.rebooting = false,
      this.slow = false,
      this.cooldownUntil,
      this.outcome,
      this.round = 0});

  /// 요청을 보내는 중(응답 대기).
  final bool sending;

  /// 명령은 나갔고 완료 신호를 기다리는 중 — "재시작 중…".
  final bool rebooting;

  /// 재시작 중인데 [kRebootSlowAfter]가 지났다 — "확인이 늦어지고 있어요".
  final bool slow;

  /// 이때까지 다시 누를 수 없다(명령 발행 뒤 60초).
  final DateTime? cooldownUntil;

  /// 마지막 재시작의 결과. [round]가 바뀌어야 새 결과다.
  final RebootOutcome? outcome;
  final int round;

  bool coolingDown(DateTime now) =>
      cooldownUntil != null && now.isBefore(cooldownUntil!);
}

/// 카메라 한 대의 재시작 대상 키.
SysTarget cameraRebootTarget(String cameraUuid) =>
    (PairTargetKind.camera, cameraUuid);

/// 기기 재시작 진행. 완료는 heartbeat로 판정한다([SysHealth.rebootedSince]).
/// 사육장은 명령 결과도 본다 — **`status`만 보지 않는다**: 기기가 거부해도
/// (`unknown_action`) `acked`로 기록되고 `result`만 다르다. 성공은
/// `result == ok`뿐이고, ok면 재부팅 직전이라 계속 기다린다.
///
/// 진행 중에는 화면이 없어도 살아 있다(2026-10-03) — 기기 상세에서 누르고
/// 카메라 탭으로 가도 라이브가 "재시작 중"을 알고, 끝나면 다시 붙는다. 끝나면
/// 놓아 준다. heartbeat 구독도 누른 뒤에만 연다 — 라이브 제어기가 이 provider를
/// 늘 듣고 있어서, 평소에 열면 라이브마다 Realtime 채널이 하나씩 붙는다.
final rebootProvider = NotifierProvider.autoDispose
    .family<RebootController, RebootState, SysTarget>(RebootController.new);

class RebootController
    extends AutoDisposeFamilyNotifier<RebootState, SysTarget> {
  Timer? _timeout;
  Timer? _slow;
  Timer? _cooldown;
  ProviderSubscription<AsyncValue<RebootCommandState?>>? _command;
  ProviderSubscription<AsyncValue<SysHealth>>? _health;
  KeepAliveLink? _alive;
  int? _uptimeBefore;
  Stopwatch? _sincePress;

  @override
  RebootState build(SysTarget target) {
    ref.onDispose(() {
      _timeout?.cancel();
      _slow?.cancel();
      _cooldown?.cancel();
      _command?.close();
      _health?.close();
    });
    return const RebootState();
  }

  RebootState _copy(
          {bool sending = false,
          bool rebooting = false,
          bool slow = false,
          DateTime? until}) =>
      RebootState(
          sending: sending,
          rebooting: rebooting,
          slow: slow,
          cooldownUntil: until,
          outcome: state.outcome,
          round: state.round);

  /// 보낼 때부터 끝날 때까지 붙잡는 것(화면 없이도 유지·heartbeat 구독).
  void _hold() {
    _alive ??= ref.keepAlive();
    _health?.close();
    // 첫 값(직결 조회)이 누르기 직전 가동 시간이다 — 이미 상세가 읽어 두었으면
    // 즉시 온다. 중간에 is_online이 false가 돼도(서버 판정 3분) 한도까지 기다린다.
    _health = ref.listen(sysHealthProvider(arg), (_, next) {
      final health = next.valueOrNull;
      if (health == null) return;
      if (state.sending) {
        _uptimeBefore ??= health.uptimeSeconds;
      } else if (state.rebooting &&
          health.rebootedSince(_uptimeBefore,
              sincePress: _sincePress?.elapsed)) {
        _finish(RebootOutcome.done);
      }
    }, fireImmediately: true);
  }

  void _release() {
    _health?.close();
    _health = null;
    _alive?.close();
    _alive = null;
  }

  Future<RebootRequest> request() async {
    if (state.sending || state.rebooting || state.coolingDown(DateTime.now())) {
      return RebootRequest.notPublished;
    }
    final (kind, id) = arg;
    _uptimeBefore = null;
    // clock — 테스트의 가짜 시계가 흘린다.
    _sincePress = clock.stopwatch()..start();
    state = _copy(sending: true);
    _hold();
    try {
      String? commandId;
      if (kind == PairTargetKind.camera) {
        if (!await ref.read(cameraRepositoryProvider).reboot(id)) {
          state = _copy();
          _release();
          return RebootRequest.notPublished;
        }
      } else {
        commandId = await ref.read(deviceHealthRepositoryProvider).reboot(id);
      }
      state = _copy(rebooting: true, until: DateTime.now().add(kRebootCooldown));
      _timeout?.cancel();
      _timeout = Timer(kRebootTimeout, () => _finish(RebootOutcome.timedOut));
      _slow?.cancel();
      _slow = Timer(kRebootSlowAfter, () {
        if (state.rebooting) {
          state = _copy(rebooting: true, slow: true, until: state.cooldownUntil);
        }
      });
      // 쿨다운이 끝나면 버튼을 다시 그린다.
      _cooldown?.cancel();
      _cooldown = Timer(kRebootCooldown, () {
        state = _copy(rebooting: state.rebooting, slow: state.slow);
      });
      if (commandId != null) _watchCommand(commandId);
      return RebootRequest.published;
    } on TerraRestException catch (e) {
      state = _copy();
      final notFound = e.statusCode == 404;
      // 해제됐거나 다른 계정 카메라 — 목록에서 빠지게 다시 읽는다. 붙잡은 것을
      // 놓기([_release]) **전에** — 놓으면 이 provider가 곧 정리될 수 있다.
      if (notFound && kind == PairTargetKind.camera) {
        ref.invalidate(camerasProvider);
      }
      _release();
      return notFound ? RebootRequest.notFound : RebootRequest.failed;
    } catch (_) {
      state = _copy();
      _release();
      return RebootRequest.failed;
    }
  }

  void _watchCommand(String commandId) {
    _command?.close();
    _command = ref.listen(rebootCommandProvider(commandId), (_, next) {
      final command = next.valueOrNull;
      if (command == null || !state.rebooting) return;
      switch (command.status) {
        case 'no_ack' || 'expired' || 'lost':
          _finish(RebootOutcome.noAck);
        case 'acked' || 'rejected':
          final result = command.result;
          if (command.status == 'acked' && result == 'ok') return; // 재부팅 직전
          if (result == null) return; // 결과가 아직 없다
          _finish(result == 'unknown_action'
              ? RebootOutcome.unsupported
              : RebootOutcome.failed);
        default:
          return; // pending·sent — 기다린다
      }
    });
  }

  void _finish(RebootOutcome outcome) {
    if (!state.rebooting) return;
    _timeout?.cancel();
    _slow?.cancel();
    _command?.close();
    _command = null;
    _sincePress = null;
    state = RebootState(
        cooldownUntil: state.cooldownUntil,
        outcome: outcome,
        round: state.round + 1);
    // 결과를 들을 화면이 있으면 그쪽이 잡고 있다 — 없으면 여기서 사라진다.
    _release();
  }
}

/// Wi-Fi 약함 배너 — 상세를 보는 동안 −75 이하가 약 1분(카메라 4번·사육장
/// 20번) 이어지면 켜고, 값이 좋아져도 유저가 닫을 때까지 둔다(깜빡임 방지).
/// 닫으면 이번 방문 동안은 다시 띄우지 않는다. 화면을 나가면 횟수도 버린다.
final weakWifiBannerProvider = NotifierProvider.autoDispose
    .family<WeakWifiBanner, bool, SysTarget>(WeakWifiBanner.new);

class WeakWifiBanner extends AutoDisposeFamilyNotifier<bool, SysTarget> {
  late final WeakSignalStreak _streak = WeakSignalStreak.forKind(arg.$1);
  bool _dismissed = false;

  @override
  bool build(SysTarget target) {
    // fireImmediately는 쓰지 않는다 — build가 끝나기 전 state를 읽으면 던진다.
    // 첫 값은 로딩→데이터 변화로 들어온다.
    ref.listen(sysHealthProvider(target), (_, next) {
      final health = next.valueOrNull;
      if (health == null || state || _dismissed) return;
      if (_streak.add(health)) state = true;
    });
    return false;
  }

  void dismiss() {
    _dismissed = true;
    state = false;
  }
}
