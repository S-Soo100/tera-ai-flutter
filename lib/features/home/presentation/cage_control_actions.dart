/// 사육장 액추에이터 제어 동작 모음.
///
/// 히터는 과열 시 개체 폐사로 이어지는 유일한 액추에이터다. 그래서 명령과
/// **안전 확인 플로우를 위젯 밖 여기 한 곳에** 둔다.
///
/// 지금 진입점은 홈의 제어 그리드(`CageControlGrid`) 하나뿐이지만, 한때
/// 라이브 아래 컴팩트 바가 함께 있었고 그때 두 경로가 안전 확인을 공유해야
/// 해서 이 모듈이 생겼다. **제어 진입점을 다시 늘린다면 반드시 여기를 경유할
/// 것** — 위젯에 명령 로직을 복붙하면 한쪽만 고쳐지고 다른 쪽이 안전장치
/// 없이 남는다.
library;

import 'dart:async';

import 'package:clock/clock.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../my_cage/domain/device_command.dart';
import '../../my_cage/domain/actuator_state.dart';
import '../../my_cage/domain/telemetry_reading.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/widgets/heater_lock_dialog.dart';
import '../../../shared/services/fan_timer_notification_service.dart';
import '../../../shared/domain/fan_actuator.dart';
import '../data/fan_choice_store.dart';
import '../data/mist_choice_store.dart';
import '../data/fan_timer_notification_resync.dart';
import '../domain/fan_timer_duration.dart';
import '../domain/mist_duration.dart';
import '../domain/mist_lock.dart';
import '../domain/schedule_device.dart';
import 'control_pending.dart';
import 'widgets/control_feedback.dart';
import 'widgets/running_timer_chip.dart';
import '../../../shared/widgets/figma_icon.dart';

/// 분무 중복 클릭 락. **기기별로 분리한다** — 전역이면 A 사육장에서 분무한 뒤
/// B 사육장으로 스와이프해도 B의 버튼이 잠긴다.
final mistLockProvider = StateProvider.family<MistLock, String>(
  (ref, deviceId) => const MistLock(lockedUntil: null),
);

/// 환기팬 직전 설정 저장소(원탭 재실행용) — [handleFanTap]·[openFanSheet]가 쓴다.
final fanChoiceStoreProvider =
    Provider<FanChoiceStore>((_) => const HiveFanChoiceStore());

/// 분무 직전 분사 시간 저장소 — 제어 시트 칩의 초기 선택.
final mistChoiceStoreProvider =
    Provider<MistChoiceStore>((_) => const HiveMistChoiceStore());

/// 확인이 끝난 명령의 뒷정리 — 팬 명령이면 완료 알림 예약을 최신 이력으로
/// 다시 맞춘다(실패한 시작은 예약을 내리고, 실패한 종료는 이전 유효 타이머를
/// 복구). 타일 카운트다운도 깨운다.
Future<void> _afterConfirm(
    ProviderContainer container, DeviceCommand command) async {
  container.invalidate(runningTimersProvider);
  if (FanActuator.values
      .any((a) => a.actions.contains(command.action.toWire()))) {
    await FanTimerNotificationResync(container.read(supabaseClientProvider),
            container.read(fanTimerNotificationServiceProvider))
        .run([command.deviceId]);
  }
}

/// 명령 1건 발행 + **기기 확인까지 대기**([controlPendingProvider]).
/// **실패를 삼키지 않는다.**
///
/// 대기하는 동안 그 사육장의 제어는 전부 잠기고, 누른 장치는 목표 상태를
/// 로딩으로 그린다(2026-09-22 — 스위치가 텔레메트리 반영까지 2~3초 원래 자리에
/// 있어 연타 → 기기 `busy` 거절이 잦았다). 거절·무응답은 16초 뒤가 아니라
/// 확인되는 즉시 알린다.
///
/// 반환값은 **기기가 받아들였는지** — 팬 타이머 알림처럼 실제로 켜졌을 때만
/// 이어져야 하는 후속 동작이 본다. 이미 대기 중이면 보내지 않고 false.
Future<bool> sendCageCommand(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  CommandAction action, {
  required ScheduleDevice device,
  bool? expectOn,
  Map<String, dynamic>? payload,
}) =>
    sendCageCommandWith(
        ProviderScope.containerOf(context, listen: false),
        ControlFeedback.of(context),
        deviceId,
        action,
        device: device,
        expectOn: expectOn,
        payload: payload);

/// [sendCageCommand]의 컨테이너 버전 — 확인은 시트가 닫힌 뒤에도 이어져야
/// 해서 context 대신 컨테이너·루트 Overlay 안내를 잡는다.
Future<bool> sendCageCommandWith(
  ProviderContainer container,
  ControlFeedback feedback,
  String deviceId,
  CommandAction action, {
  required ScheduleDevice device,
  bool? expectOn,
  Map<String, dynamic>? payload,
}) async {
  final pending = container.read(controlPendingProvider(deviceId).notifier);
  if (!pending.begin(device, expectOn)) return false;
  final DeviceCommand command;
  try {
    command = await container
        .read(moduleCommandSenderProvider.notifier)
        .send(deviceId, action, payload: payload);
  } catch (e, st) {
    pending.cancel();
    debugPrint('[cage-control] $action failed: $e\n$st');
    if (feedback.mounted) feedback.show('module_command_failed'.tr());
    return false;
  }
  final outcome = await pending.confirm(command);
  showControlOutcome(feedback, outcome);
  await _afterConfirm(container, command);
  return outcome == ControlOutcome.ok;
}

/// PRD §3.4 히터 제어 — **안전 확인을 거친다.**
///
/// 2단 안전 플로우:
/// ① 안전잠금(DS18B20 50°C 초과/통신오류)이 걸려 있으면 해제 다이얼로그부터
/// ② 아니면 조작 확인 다이얼로그를 받고 나서 전송
///
/// **보내는 건 toggle이 아니라 절대 명령이다.** 뒤집기는 기기의 현재 상태를
/// 전제하는데, 그 전제가 어긋나면 끄려던 조작이 켠다 — 히터에서는 과열로
/// 이어진다. 켜져 있으면 `heater_off`, 아니면 `heater_on`을 보낸다.
Future<void> handleHeaterTap(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  TelemetryReading? telemetry,
) async {
  if (telemetry?.heaterLocked ?? false) {
    await showHeaterLockDialog(context, ref, deviceId: deviceId);
    return;
  }

  final isOn = telemetry?.heaterState == ActuatorState.on;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('module_heater_confirm_title'.tr()),
      // 무엇을 하려는지 문구로 못박는다. "조작하시겠습니까"만으로는 켜는 건지
      // 끄는 건지 몰라, 과열 상황에서 끄려던 사람이 확인을 망설인다.
      content: Text((isOn
              ? 'module_heater_confirm_body_off'
              : 'module_heater_confirm_body_on')
          .tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('module_heater_confirm_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warning,
            foregroundColor: Colors.white,
          ),
          child: Text('module_heater_confirm_yes'.tr()),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await sendCageCommand(
    context,
    ref,
    deviceId,
    isOn ? CommandAction.heaterOff : CommandAction.heaterOn,
    device: ScheduleDevice.heater,
    expectOn: !isOn,
  );
}

ScheduleDevice _fanDevice(FanActuator a) =>
    a == FanActuator.cooling ? ScheduleDevice.cool : ScheduleDevice.fan;

/// 켜진 팬을 끈다 — `fan_off`/`fan2_off` 절대 명령. 타이머가 돌고 있었다면
/// 취소된 것이라 예약된 완료 알림도 내리고 타일 카운트다운을 깨운다.
/// 홈 제어 시트(`DeviceControlSheet`)의 전원 스위치가 부른다.
Future<void> stopFan(
  BuildContext context,
  WidgetRef ref,
  String deviceId, {
  FanActuator actuator = FanActuator.ventilation,
}) async {
  // 서비스를 await 전에 잡아 둔다 — 전송 중 화면을 떠나도 예약된 로컬 알림은
  // 취소돼야 한다(ref는 unmount 후 못 쓴다).
  final timerNotifs = ref.read(fanTimerNotificationServiceProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  final sent = await sendCageCommand(
      context, ref, deviceId, CommandActionWire.fromWire(actuator.offAction),
      device: _fanDevice(actuator), expectOn: false);
  if (sent) {
    await timerNotifs.onFanCommandSent(deviceId, actuator.offAction, null);
  }
  // 확인을 기다리는 사이 시트가 닫혔을 수 있다 — ref 대신 컨테이너로 깨운다.
  container.invalidate(runningTimersProvider);
}

/// `fan_on`(+타이머) 전송 + 완료 알림 예약 + 칩 갱신 + 켜짐 스낵바.
///
/// 홈 제어 시트의 전원 스위치(꺼짐→켜짐)와 작동 시간 칩(켜진 채 변경)이
/// 부른다. 선택만으로는 보내지 않는다(2026-09-14 결정) — 스위치·칩 탭이
/// 명시적 시작이다. 반환값은 기기가 받아들였는지 — 시트가 칩 선택을 되돌릴지
/// 정한다(2026-09-25: 실패해도 칩이 새 값으로 남아 연장된 것처럼 보였다).
Future<bool> startFan(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  FanTimerDuration? duration, {
  FanActuator actuator = FanActuator.ventilation,
  bool wasOn = false,
}) async {
  // await 전에 잡는다 — 전송 중 화면을 떠나도 알림 예약/스낵바는 살아야 한다.
  final timerNotifs = ref.read(fanTimerNotificationServiceProvider);
  final feedback = ControlFeedback.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  final sent = await sendCageCommand(
    context,
    ref,
    deviceId,
    CommandActionWire.fromWire(actuator.onAction),
    device: _fanDevice(actuator),
    // 켜진 채 시간만 바꾸면 상태 변화가 없어 ACK로만 확인한다.
    expectOn: wasOn ? null : true,
    payload: duration?.payload,
  );
  // 타이머면 만료 시각에 완료 알림을 예약하고, '계속 켜기'면 기존 예약을
  // 내린다(기존 타이머 대체). 판단은 서비스 쪽 plan이 한다.
  if (sent) {
    await timerNotifs.onFanCommandSent(
      deviceId,
      actuator.onAction,
      duration == null ? null : duration.minutes * 60000,
    );
  }
  // '계속 켜기'(duration 없음)도 invalidate한다 — duration 없는 fan_on은
  // 진행 중이던 타이머를 대체(소멸)시키므로, 안 깨우면 옛 칩이 만료 시각까지
  // 가짜 카운트다운을 돈다. 확인 대기 사이 시트가 닫혔을 수 있어 컨테이너로.
  container.invalidate(runningTimersProvider);

  if (!sent) return false; // 실패 안내는 sendCageCommand가 이미 냈다.
  feedback.show(duration == null
      ? (actuator == FanActuator.cooling
              ? 'home_cooling_started_steady'
              : 'home_fan_started_steady')
          .tr()
      : (actuator == FanActuator.cooling
              ? 'home_cooling_started_timer'
              : 'home_fan_started_timer')
          .tr(args: [duration.labelKey.tr()]));
  return true;
}

/// 1회 즉시 분사.
///
/// `duration_ms`만 보내고 **OFF는 보내지 않는다** — 펌웨어가 내부 타이머로
/// 자동으로 끈다. 앱에서 ON→지연 OFF로 펄스를 흉내내면 앱이 백그라운드로 가는
/// 순간 펌프가 계속 돈다.
///
/// 2026-08-12 이전에는 `relay_pulse` 계약이 없어 `relay_toggle`을 1회만 보내는
/// 우회를 썼다(실DB 144건). `mist`가 그 정공법이다.
Future<void> mistOnce(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  MistDuration duration,
) =>
    sendMistWith(ProviderScope.containerOf(context, listen: false),
        ControlFeedback.of(context), deviceId, duration);

/// 이어 보내는 분무의 진행 — 기기별. 타일 "분사 중 2/3"과 시트 [중지]가 읽는다.
@immutable
class MistRun {
  const MistRun({required this.duration, required this.part});
  final MistDuration duration;

  /// 지금 보내는(또는 뿌리는) 회차, 1부터.
  final int part;
}

final mistRunProvider =
    StateProvider.family<MistRun?, String>((ref, deviceId) => null);

final _mistStopRequested = <String>{};

/// 시트 [중지] — 남은 회차를 보내지 않는다(이미 뿌리는 3초는 펌웨어가 끝낸다).
void stopMistRun(String deviceId) => _mistStopRequested.add(deviceId);

/// 다음 회차가 이만큼 넘게 늦으면 보내지 않는다 — 앱이 백그라운드에서 멈췄다
/// 깨어나 몇 분 뒤 뜬금없이 분사하면 안 된다.
const kMistPartLateLimit = Duration(seconds: 10);

/// [mistOnce]의 컨테이너 버전.
///
/// 서버가 6000·9000을 받기 전까지 6·9초는 3초를 2·3번 **이어 보낸다**
/// (2026-09-25 사용자 결정, [MistDuration.parts]). 회차마다 기기 ACK를 받고,
/// 분사가 끝나고 2초 쉰 뒤([MistLock.partInterval]) 다음을 보낸다. 중간에
/// 거절·무응답·중지·지연이 나면 남은 회차는 보내지 않고 **실제로 뿌린 시간**을
/// 알린다 — "9초 뿌렸다"고 믿는데 3초면 습도 관리를 잘못 판단한다.
Future<void> sendMistWith(
  ProviderContainer container,
  ControlFeedback feedback,
  String deviceId,
  MistDuration duration,
) async {
  final pending = container.read(controlPendingProvider(deviceId).notifier);
  // 다른 제어의 확인을 기다리는 중이면 보내지 않는다. 실행 취소 창 동안 타일은
  // 잠기지만, 만에 하나 겹치면 조용히 삼키지 않고 실패로 알린다 — "분무가
  // 실행됩니다"를 봤는데 안 나가면 습도에 대한 거짓 확신이 된다.
  if (container.read(controlPendingProvider(deviceId)) != null) {
    feedback.toast('home_mist_failed_toast'.tr(), icon: FigmaIcons.cancel);
    return;
  }
  final lockNotifier = container.read(mistLockProvider(deviceId).notifier);
  MistLock? lock;
  // 이 분무가 건 잠금만 푼다 — 실패로 일찍 풀린 뒤 새 분무가 건 잠금을 옛
  // 타이머가 지우면 안 된다.
  void unlock() {
    if (lockNotifier.mounted && identical(lockNotifier.state, lock)) {
      lockNotifier.state = const MistLock(lockedUntil: null);
    }
  }

  void lockUntil(DateTime until) {
    final next = lock = MistLock(lockedUntil: until);
    lockNotifier.state = next;
    // 만료를 깨우는 주체를 명시적으로 둔다. 예전엔 무관한 provider(telemetry
    // 3초 틱)가 우연히 리빌드해 주기를 기다렸고, 그게 멈추면 버튼이 잠긴 채
    // 남았다.
    final wait = until.difference(clock.now());
    Timer(wait.isNegative ? Duration.zero : wait, () {
      if (lockNotifier.mounted && identical(lockNotifier.state, next)) {
        lockNotifier.state = const MistLock(lockedUntil: null);
      }
    });
  }

  lockUntil(clock.now().add(MistLock.lockFor(duration)));
  final run = container.read(mistRunProvider(deviceId).notifier);
  _mistStopRequested.remove(deviceId);

  final parts = duration.parts;
  final partSeconds = duration.seconds ~/ parts;
  var done = 0;
  ControlOutcome? failure;
  var sendFailed = false;
  var interrupted = false; // 중지·지연
  DateTime? lastIssuedAt;
  var planned = clock.now();
  for (var i = 0; i < parts; i++) {
    if (i > 0) {
      final wait = planned.difference(clock.now());
      if (!wait.isNegative) await Future<void>.delayed(wait);
      if (_mistStopRequested.contains(deviceId) ||
          clock.now().difference(planned) > kMistPartLateLimit) {
        interrupted = true;
        break;
      }
    }
    if (run.mounted) run.state = MistRun(duration: duration, part: i + 1);
    if (!pending.begin(ScheduleDevice.mist, null)) {
      failure = ControlOutcome.busy;
      break;
    }
    lastIssuedAt = clock.now();
    planned = lastIssuedAt.add(MistLock.partInterval);
    final DeviceCommand command;
    try {
      command = await container
          .read(moduleCommandSenderProvider.notifier)
          .send(deviceId, CommandAction.mist, payload: duration.partPayload);
    } catch (e, st) {
      pending.cancel();
      debugPrint('[cage-control] mist failed: $e\n$st');
      sendFailed = true;
      break;
    }
    // mist 자체도 유실될 수 있다 — 분사가 안 됐는데 "분사했어요"로 끝나면
    // 사육 환경(습도)에 대한 거짓 확신이 된다. 그래서 기기 ACK를 받고 센다.
    final outcome = await pending.confirm(command);
    if (outcome != ControlOutcome.ok) {
      failure = outcome;
      break;
    }
    done++;
  }
  if (run.mounted) run.state = null;
  _mistStopRequested.remove(deviceId);

  if (done == parts) {
    // Figma 1106:6646 토스트 "분무가 실행되었습니다".
    feedback.toast('home_mist_done_toast'.tr());
    return;
  }
  if (failure == ControlOutcome.unconfirmed && lastIssuedAt != null) {
    // 응답이 늦다 — 늦게 실행될 수 있어 서버가 확정하는 30초까지 잡아 둔다.
    lockUntil(lastIssuedAt.add(MistLock.unconfirmedHold));
  } else {
    // 거절·미전달·중지면 남은 분사는 없다 — 잠금·"작동 중"을 푼다. 이미
    // 뿌리는 회차가 있으면 그 3초는 텔레메트리가 보여 준다.
    unlock();
  }
  if (done > 0) {
    feedback.show('home_mist_partial'
        .tr(args: ['${duration.seconds}', '${done * partSeconds}']));
    return;
  }
  if (sendFailed) {
    feedback.toast('home_mist_failed_toast'.tr(), icon: FigmaIcons.cancel);
  } else if (failure == ControlOutcome.unconfirmed) {
    feedback.show('home_mist_unconfirmed'.tr());
  } else if (failure != null) {
    showControlOutcome(feedback, failure);
  } else if (interrupted) {
    feedback.toast('home_mist_cancelled_toast'.tr(), icon: FigmaIcons.cancel);
  }
}

/// 분무 대기 창(실행 취소 가능) — 기기별. 시트 CTA가 비활성 근거로 읽는다.
final mistPendingProvider =
    StateProvider.family<bool, String>((ref, deviceId) => false);

/// 실행 취소 창 길이 — Figma 1106:6790 스낵바 "잠시 후 분무가 실행됩니다 · 2초".
const kMistUndoWindow = Duration(seconds: 2);

/// 진행 중인 분무 대기 — 테스트·취소용. 기기별 하나만.
final _pendingMist = <String, Completer<bool>>{};

/// 시트 "1회 분사 시작"(계획 A5, 디자이너 메모 "터치→비활성→스낵바→완료
/// 토스트→재활성"): 바로 보내지 않고 [kMistUndoWindow] 동안 '실행 취소'를
/// 둔다. 창이 지나면 [duration]만큼 분무를 보낸다. 취소하면 토스트
/// "분무 실행을 취소했습니다". 대기 중·잠금 중엔 다시 누를 수 없다.
///
/// 안내는 루트 Overlay 맨 위에 뜬다([ControlFeedback]) — 스낵바였을 때는 시트
/// 뒤에 그려져 '실행 취소'를 누를 수 없었다(2026-09-25). 시트가 닫혀도 대기는
/// 계속되고 명령은 나간다 — 누른 의도는 명시적이었다(리뷰 2026-09-16).
Future<void> mistWithUndo(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  MistDuration duration,
) async {
  final pending = ref.read(mistPendingProvider(deviceId).notifier);
  if (pending.state ||
      ref.read(controlPendingProvider(deviceId)) != null ||
      ref.read(mistRunProvider(deviceId)) != null ||
      ref.read(mistLockProvider(deviceId)).isLocked(DateTime.now())) {
    return;
  }
  pending.state = true;
  final container = ProviderScope.containerOf(context, listen: false);
  final feedback = ControlFeedback.of(context);
  final done = Completer<bool>(); // true = 취소
  _pendingMist[deviceId] = done;
  final timer = Timer(kMistUndoWindow, () {
    if (!done.isCompleted) done.complete(false);
  });
  final close = feedback.show('home_mist_pending'.tr(),
      actionLabel: 'home_mist_undo'.tr(),
      duration: kMistUndoWindow,
      onAction: () {
        if (!done.isCompleted) done.complete(true);
      });
  final cancelled = await done.future;
  timer.cancel();
  _pendingMist.remove(deviceId);
  if (pending.mounted) pending.state = false;
  close();
  if (cancelled) {
    feedback.toast('home_mist_cancelled_toast'.tr(), icon: FigmaIcons.cancel);
    return;
  }
  await sendMistWith(container, feedback, deviceId, duration);
}

/// 테스트용 — 대기 중인 분무를 코드에서 취소한다. 없으면 false.
@visibleForTesting
bool cancelPendingMist(String deviceId) {
  final c = _pendingMist[deviceId];
  if (c == null || c.isCompleted) return false;
  c.complete(true);
  return true;
}

/// LED 명령 payload. 릴레이 보드엔 brightness를 싣지 않는다 — 서버·펌웨어가
/// 무시하긴 하지만 실DB `led_*` 이력에 의미 없는 payload를 남기지 않는다.
/// 끄기·비대상이면 null. `duration_ms`는 싣지 않는다 — 펌웨어가 LED에서는
/// 읽지 않고 그냥 켠 뒤 `ok`를 보내 아무도 "안 꺼짐"을 알 수 없다(2026-09-16
/// 회신 §1.4, A안 확정).
Map<String, dynamic>? ledCommandPayload(
    {required bool on, required bool dimmable, int? brightness}) {
  if (!on) return null;
  if (!dimmable || brightness == null) return null;
  return {'brightness': brightness};
}
