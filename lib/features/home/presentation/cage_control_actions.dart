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
import '../data/fan_timer_notification_resync.dart';
import '../domain/fan_timer_duration.dart';
import '../domain/mist_duration.dart';
import '../domain/mist_lock.dart';
import '../domain/running_timer.dart';
import 'widgets/running_timer_chip.dart';
import '../../my_cage/presentation/widgets/clip_toast.dart';
import '../../../shared/widgets/figma_icon.dart';

/// 분무 중복 클릭 락. **기기별로 분리한다** — 전역이면 A 사육장에서 분무한 뒤
/// B 사육장으로 스와이프해도 B의 버튼이 잠긴다.
final mistLockProvider = StateProvider.family<MistLock, String>(
  (ref, deviceId) => const MistLock(lockedUntil: null),
);

/// 환기팬 직전 설정 저장소(원탭 재실행용) — [handleFanTap]·[openFanSheet]가 쓴다.
final fanChoiceStoreProvider =
    Provider<FanChoiceStore>((_) => const HiveFanChoiceStore());

/// 발행한 명령이 [kCommandAckGrace] 안에 ACK되는지 지켜본다.
///
/// mist 블랙아웃(핸드오프 `backend-handoff-2026-09-07-mist-blackout.md`) 중의
/// 명령은 서버 `sent`까지만 가고 기기에 닿지 않는데, 서버에 sent 만료가 없어
/// 앱이 말해주지 않으면 "눌렀는데 아무 일도 없음"이 된다. 유예 후에도
/// 미ACK면 스낵바로 알리고, 타이머 칩 계산도 깨운다([RunningTimer.fanTimerFrom]의
/// 유예 게이트와 한 쌍 — 안 깨우면 다음 재검증까지 최대 30초 가짜 칩이 돈다).
///
/// messenger·client는 호출 시점에 잡아 둔다 — 타이머가 울릴 때쯤 화면을
/// 떠났을 수 있고, 그때 context로 lookup하면 죽은 엘리먼트를 만진다.
void _watchCommandAck(
  BuildContext context,
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  DeviceCommand command,
) {
  final client = ref.read(supabaseClientProvider);
  final timerNotifs = ref.read(fanTimerNotificationServiceProvider);
  Timer(kCommandAckGrace + const Duration(seconds: 1), () async {
    Map<String, dynamic>? row;
    try {
      row = await client
          .from('commands')
          .select('status, result')
          .eq('id', command.id)
          .maybeSingle();
    } catch (_) {
      return; // 조회 실패는 유실 확정이 아니다 — 겁주지 않는다.
    }
    final status = row?['status'] as String?;
    const undelivered = {'pending', 'sent', 'expired', 'lost'};
    final failed =
        status == 'rejected' || (status == 'acked' && row?['result'] != 'ok');
    if (messenger.mounted && (failed || undelivered.contains(status))) {
      messenger.showSnackBar(SnackBar(
          content: Text(
        (failed ? 'module_command_failed' : 'module_command_no_ack').tr(),
      )));
    }
    // 화면을 떠났으면 ref가 죽어 있다 — 칩은 어차피 다음 진입 때 새로 계산된다.
    if (context.mounted) ref.invalidate(runningTimersProvider);
    if (FanActuator.values
        .any((a) => a.actions.contains(command.action.toWire()))) {
      // 실패한 시작은 예약을 내리고, 실패한 종료는 이전 유효 타이머를 복구한다.
      // 최신 이력으로 계산하므로 더 나중에 보낸 명령의 알림을 지우지 않는다.
      await FanTimerNotificationResync(client, timerNotifs)
          .run([command.deviceId]);
    }
  });
}

/// 명령 1건 발행. **실패를 삼키지 않는다.**
///
/// onTap은 VoidCallback이라 여기서 던지면 unhandled async error로 콘솔에만
/// 남고 사용자는 "눌렀는데 아무 일도 안 일어남"을 기기 고장으로 오해한다.
/// 그래서 여기서 잡아 토스트로 알린다. 반환값은 전송 성공 여부 — 팬 타이머
/// 알림처럼 "명령이 실제로 나갔을 때만" 이어져야 하는 후속 동작이 본다.
///
/// 전송 성공 후에는 [_watchCommandAck]로 ACK를 지켜본다 — "전송 성공"은
/// 서버에 닿았다는 뜻이지 기기가 받았다는 뜻이 아니다(mist 블랙아웃 유실).
Future<bool> sendCageCommand(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  CommandAction action, {
  Map<String, dynamic>? payload,
}) async {
  // await 전에 잡는다 — 전송 중 화면을 떠나면 of(context)를 못 쓴다.
  final messenger = ScaffoldMessenger.of(context);
  try {
    final command = await ref
        .read(moduleCommandSenderProvider.notifier)
        .send(deviceId, action, payload: payload);
    // 전송 중 화면을 떠났으면 감시 생략 — ref가 죽어 있고, 칩도 이 화면 것이다.
    if (context.mounted) _watchCommandAck(context, ref, messenger, command);
    return true;
  } catch (e, st) {
    debugPrint('[cage-control] $action failed: $e\n$st');
    messenger.showSnackBar(
      SnackBar(content: Text('module_command_failed'.tr())),
    );
    return false;
  }
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
  );
}

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
  final sent = await sendCageCommand(
      context, ref, deviceId, CommandActionWire.fromWire(actuator.offAction));
  if (sent) {
    await timerNotifs.onFanCommandSent(deviceId, actuator.offAction, null);
  }
  // await 뒤라 mounted 재확인 — 전송 중 화면을 떠났으면 ref는 죽어 있다.
  if (context.mounted) ref.invalidate(runningTimersProvider);
}

/// `fan_on`(+타이머) 전송 + 완료 알림 예약 + 칩 갱신 + 켜짐 스낵바.
///
/// 홈 제어 시트의 전원 스위치(꺼짐→켜짐)와 작동 시간 칩(켜진 채 변경)이
/// 부른다. 선택만으로는 보내지 않는다(2026-09-14 결정) — 스위치·칩 탭이
/// 명시적 시작이다.
Future<void> startFan(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  FanTimerDuration? duration, {
  FanActuator actuator = FanActuator.ventilation,
}) async {
  // await 전에 잡는다 — 전송 중 화면을 떠나도 알림 예약/스낵바는 살아야 한다.
  final timerNotifs = ref.read(fanTimerNotificationServiceProvider);
  final messenger = ScaffoldMessenger.of(context);

  final sent = await sendCageCommand(
    context,
    ref,
    deviceId,
    CommandActionWire.fromWire(actuator.onAction),
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
  // 가짜 카운트다운을 돈다. await 뒤라 mounted 재확인.
  if (context.mounted) ref.invalidate(runningTimersProvider);

  if (!sent) return; // 실패 스낵바는 sendCageCommand가 이미 냈다.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(duration == null
            ? (actuator == FanActuator.cooling
                    ? 'home_cooling_started_steady'
                    : 'home_fan_started_steady')
                .tr()
            : (actuator == FanActuator.cooling
                    ? 'home_cooling_started_timer'
                    : 'home_fan_started_timer')
                .tr(args: [duration.labelKey.tr()])),
      ),
    );
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
) async {
  final lockNotifier = ref.read(mistLockProvider(deviceId).notifier);
  lockNotifier.state = MistLock.startingAt(DateTime.now());
  // 만료를 깨우는 주체를 명시적으로 둔다. 예전엔 무관한 provider(telemetry
  // 3초 틱)가 우연히 리빌드해 주기를 기다렸고, 그게 멈추면 버튼이 잠긴 채
  // 남았다.
  Timer(MistLock.duration, () {
    lockNotifier.state = const MistLock(lockedUntil: null);
  });
  // await 전에 잡는다 — sendCageCommand와 같은 이유.
  final messenger = ScaffoldMessenger.of(context);
  try {
    final command = await ref.read(moduleCommandSenderProvider.notifier).send(
          deviceId,
          CommandAction.mist,
          payload: duration.payload,
        );
    // mist 자체도 유실될 수 있다 — 분사가 안 됐는데 "분사했어요"로 끝나면
    // 사육 환경(습도)에 대한 거짓 확신이 된다.
    if (context.mounted) _watchCommandAck(context, ref, messenger, command);
    // Figma 1106:6646 토스트 "분무가 실행되었습니다".
    if (context.mounted) {
      showClipToast(context, text: 'home_mist_done_toast'.tr());
    }
  } catch (e, st) {
    debugPrint('[cage-control] mist failed: $e\n$st');
    if (context.mounted) {
      showClipToast(context,
          text: 'home_mist_failed_toast'.tr(), icon: FigmaIcons.cancel);
    }
  }
}

/// 분무 대기 창(실행 취소 가능) — 기기별. 시트 CTA가 비활성 근거로 읽는다.
final mistPendingProvider =
    StateProvider.family<bool, String>((ref, deviceId) => false);

/// 실행 취소 창 길이 — Figma 1106:6790 스낵바 "잠시 후 분무가 실행됩니다 · 2초".
const kMistUndoWindow = Duration(seconds: 2);

/// 시트 "1회 분사 시작"(계획 A5, 디자이너 메모 "터치→비활성→스낵바→완료
/// 토스트→재활성"): 바로 보내지 않고 [kMistUndoWindow] 동안 스낵바에
/// '실행 취소'를 둔다. 창이 지나면 [mistOnce]가 3초 분무를 보낸다. 취소하면
/// 토스트 "분무 실행을 취소했습니다". 대기 중·잠금 중엔 다시 누를 수 없다.
///
/// 시트가 닫혀도 대기는 계속된다 — 누른 의도는 명시적이었고 스낵바 취소는
/// 홈 화면에 남아 있다.
Future<void> mistWithUndo(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) async {
  final pending = ref.read(mistPendingProvider(deviceId).notifier);
  if (pending.state || ref.read(mistLockProvider(deviceId)).isLocked(DateTime.now())) {
    return;
  }
  pending.state = true;
  final messenger = ScaffoldMessenger.of(context);
  var cancelled = false;
  final controller = messenger.showSnackBar(SnackBar(
    duration: kMistUndoWindow + const Duration(milliseconds: 300),
    content: Text('home_mist_pending'.tr()),
    action: SnackBarAction(
        label: 'home_mist_undo'.tr(), onPressed: () => cancelled = true),
  ));
  final reason = await Future.any<SnackBarClosedReason>([
    controller.closed,
    Future.delayed(kMistUndoWindow, () => SnackBarClosedReason.timeout),
  ]);
  if (cancelled || reason == SnackBarClosedReason.action) {
    if (pending.mounted) pending.state = false;
    if (context.mounted) {
      showClipToast(context,
          text: 'home_mist_cancelled_toast'.tr(), icon: FigmaIcons.cancel);
    }
    return;
  }
  messenger.hideCurrentSnackBar();
  if (pending.mounted) pending.state = false;
  if (!context.mounted) return;
  await mistOnce(context, ref, deviceId, MistDuration.threeSeconds);
}

// 분무 지속시간 선택 시트(openMistSheet)·mistDurationProvider는 2026-09-07
// 사용자 지시로 폐지 — 홈 분무 타일은 무조건 3초 분사(cage_control_grid).
// 예약 편집기의 분무 시간 선택(schedule_editor_sheet)은 별개로 유지된다.

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
