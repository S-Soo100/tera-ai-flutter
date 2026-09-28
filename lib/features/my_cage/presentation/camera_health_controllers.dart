import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/terra_rest_client.dart';
import '../domain/camera_health.dart';
import 'my_cage_providers.dart';

/// 재시작 요청을 보낸 결과 — 화면이 안내를 고른다(요청서 §2-2 표).
enum CameraRebootRequest { published, notPublished, notFound, failed }

/// 재시작 뒤 결과 — 완료 신호가 왔거나 2분 동안 안 왔다.
enum CameraRebootOutcome { done, timedOut }

class CameraRebootState {
  const CameraRebootState(
      {this.sending = false,
      this.rebooting = false,
      this.cooldownUntil,
      this.outcome,
      this.round = 0});

  /// 요청을 보내는 중(응답 대기).
  final bool sending;

  /// 명령은 나갔고 완료 신호를 기다리는 중 — "재시작 중…".
  final bool rebooting;

  /// 이때까지 다시 누를 수 없다(명령 발행 뒤 60초).
  final DateTime? cooldownUntil;

  /// 마지막 재시작의 결과. [round]가 바뀌어야 새 결과다.
  final CameraRebootOutcome? outcome;
  final int round;

  bool coolingDown(DateTime now) =>
      cooldownUntil != null && now.isBefore(cooldownUntil!);
}

/// 카메라 재시작 진행(요청서 §2-2·2-3). 카메라의 ack는 오지 않아 `clip_stats`의
/// 가동 시간이 명령 전보다 줄고 리셋 사유가 MQTT 재시작이면 완료로 본다.
/// 화면을 나가면(autoDispose) 진행 표시는 버린다 — 재진입 복원 불필요.
final cameraRebootProvider = NotifierProvider.autoDispose
    .family<CameraRebootController, CameraRebootState, String>(
        CameraRebootController.new);

class CameraRebootController
    extends AutoDisposeFamilyNotifier<CameraRebootState, String> {
  Timer? _timeout;
  Timer? _cooldown;
  int? _uptimeBefore;

  @override
  CameraRebootState build(String cameraUuid) {
    ref.onDispose(() {
      _timeout?.cancel();
      _cooldown?.cancel();
    });
    // 재시작 중이면 heartbeat마다 완료 신호를 본다. 중간에 is_online이 false가
    // 돼도(서버 판정 3분) 2분 한도까지는 그대로 기다린다.
    ref.listen(cameraHealthProvider(cameraUuid), (_, next) {
      final health = next.valueOrNull;
      if (health == null || !state.rebooting) return;
      if (health.rebootedSince(_uptimeBefore)) {
        _finish(CameraRebootOutcome.done);
      }
    });
    return const CameraRebootState();
  }

  Future<CameraRebootRequest> request() async {
    final now = DateTime.now();
    if (state.sending || state.rebooting || state.coolingDown(now)) {
      return CameraRebootRequest.notPublished;
    }
    // 누르기 직전 가동 시간 — 완료 판정의 기준(요청서 §2-3).
    _uptimeBefore =
        ref.read(cameraHealthProvider(arg)).valueOrNull?.uptimeSeconds;
    state = CameraRebootState(
        sending: true, outcome: state.outcome, round: state.round);
    try {
      final published = await ref.read(cameraRepositoryProvider).reboot(arg);
      if (!published) {
        state = CameraRebootState(outcome: state.outcome, round: state.round);
        return CameraRebootRequest.notPublished;
      }
      final until = DateTime.now().add(kRebootCooldown);
      state = CameraRebootState(
          rebooting: true,
          cooldownUntil: until,
          outcome: state.outcome,
          round: state.round);
      _timeout?.cancel();
      _timeout =
          Timer(kRebootTimeout, () => _finish(CameraRebootOutcome.timedOut));
      // 쿨다운이 끝나면 버튼을 다시 그린다.
      _cooldown?.cancel();
      _cooldown = Timer(kRebootCooldown, () {
        state = CameraRebootState(
            rebooting: state.rebooting,
            outcome: state.outcome,
            round: state.round);
      });
      return CameraRebootRequest.published;
    } on TerraRestException catch (e) {
      state = CameraRebootState(outcome: state.outcome, round: state.round);
      return e.statusCode == 404
          ? CameraRebootRequest.notFound
          : CameraRebootRequest.failed;
    } catch (_) {
      state = CameraRebootState(outcome: state.outcome, round: state.round);
      return CameraRebootRequest.failed;
    }
  }

  void _finish(CameraRebootOutcome outcome) {
    if (!state.rebooting) return;
    _timeout?.cancel();
    state = CameraRebootState(
        cooldownUntil: state.cooldownUntil,
        outcome: outcome,
        round: state.round + 1);
  }
}

/// Wi-Fi 약함 배너(요청서 §3) — 상세를 보는 동안 −75 이하가 연속 4번(약 1분)이면
/// 켜고, 값이 좋아져도 유저가 닫을 때까지 둔다(깜빡임 방지). 닫으면 이번 방문
/// 동안은 다시 띄우지 않는다. 화면을 나가면(autoDispose) 횟수도 버린다.
final weakWifiBannerProvider = NotifierProvider.autoDispose
    .family<WeakWifiBanner, bool, String>(WeakWifiBanner.new);

class WeakWifiBanner extends AutoDisposeFamilyNotifier<bool, String> {
  final _streak = WeakSignalStreak();
  bool _dismissed = false;

  @override
  bool build(String cameraUuid) {
    ref.listen(cameraHealthProvider(cameraUuid), (_, next) {
      final health = next.valueOrNull;
      if (health == null || state || _dismissed) return;
      if (_streak.add(health)) state = true;
    });
    // fireImmediately는 쓰지 않는다 — build가 끝나기 전 state를 읽으면 던진다.
    // 한 번 약한 값만으로는 켜지지 않으니(연속 4번) 첫 값을 놓쳐도 된다.
    return false;
  }

  void dismiss() {
    _dismissed = true;
    state = false;
  }
}
