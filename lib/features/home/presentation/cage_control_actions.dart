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
import '../../../core/theme/app_styles.dart';
import '../../my_cage/domain/device_command.dart';
import '../../my_cage/domain/actuator_state.dart';
import '../../my_cage/domain/telemetry_reading.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/widgets/heater_lock_dialog.dart';
import '../../../shared/services/fan_timer_notification_service.dart';
import '../domain/fan_timer_duration.dart';
import '../domain/mist_duration.dart';
import '../domain/mist_lock.dart';
import '../domain/running_timer.dart';
import 'widgets/running_timer_chip.dart';

/// 분무 중복 클릭 락. **기기별로 분리한다** — 전역이면 A 사육장에서 분무한 뒤
/// B 사육장으로 스와이프해도 B의 버튼이 잠긴다.
final mistLockProvider = StateProvider.family<MistLock, String>(
  (ref, deviceId) => const MistLock(lockedUntil: null),
);


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
  Timer(kCommandAckGrace + const Duration(seconds: 1), () async {
    Map<String, dynamic>? row;
    try {
      row = await client
          .from('commands')
          .select('status')
          .eq('id', command.id)
          .maybeSingle();
    } catch (_) {
      return; // 조회 실패는 유실 확정이 아니다 — 겁주지 않는다.
    }
    final status = row?['status'] as String?;
    // 전달 실패 = 기기에 닿지 못한 상태 전부. pending/sent(미ACK 잔류)에 더해
    // 서버가 만료 마킹을 먼저 붙인 경우(expired, 예정된 lost — 펌웨어 회신
    // 2026-09-07 §6.3)도 같은 뜻이다. acked/rejected는 기기가 받았다는
    // 뜻이라 제외.
    const undelivered = {'pending', 'sent', 'expired', 'lost'};
    if (!undelivered.contains(status)) return;
    messenger.showSnackBar(
      SnackBar(content: Text('module_command_no_ack'.tr())),
    );
    // 화면을 떠났으면 ref가 죽어 있다 — 칩은 어차피 다음 진입 때 새로 계산된다.
    if (context.mounted) ref.invalidate(runningTimersProvider);
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

/// 팬 제어 — 꺼져 있으면 시트(계속 켜기/일회성 타이머), 켜져 있으면 바로 끈다.
///
/// 끄기에 시트를 안 두는 이유: 끄기는 망설일 게 없고, **타이머 취소도
/// `fan_off`다**(2026-08-14 핸드오프 §1.3). 타이머는 `fan_on` +
/// `payload.duration_ms`로 걸고 **펌웨어가 스스로 끈다** — 분무와 같은 이유로
/// 앱이 지연 OFF를 흉내내지 않는다. 히터와 달리 안전 확인은 없지만 명령은
/// 똑같이 절대 상태로 보낸다.
Future<void> handleFanTap(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  TelemetryReading? telemetry,
) async {
  // 서비스를 await 전에 잡아 둔다 — 전송 중 화면을 떠나도 예약된 로컬 알림은
  // 취소/등록돼야 한다(ref는 unmount 후 못 쓴다).
  final timerNotifs = ref.read(fanTimerNotificationServiceProvider);

  final isOn = telemetry?.fan == ActuatorState.on;
  if (isOn) {
    final sent =
        await sendCageCommand(context, ref, deviceId, CommandAction.fanOff);
    // 타이머 가동 중이었다면 취소된 것 — 예약된 완료 알림도 함께 내린다.
    if (sent) {
      await timerNotifs.onFanCommandSent(
          deviceId, CommandAction.fanOff.toWire(), null);
    }
    // 칩을 깨워 내린다.
    // await 뒤라 mounted 재확인 — 전송 중 화면을 떠났으면 ref는 죽어 있다.
    if (context.mounted) ref.invalidate(runningTimersProvider);
    return;
  }

  // (FanTimerDuration?,) — null이면 '계속 켜기', 값이 있으면 일회성 타이머.
  // 시트 닫힘(null 반환)과 '계속 켜기'를 구분하려고 레코드로 감싼다.
  final picked = await showModalBottomSheet<(FanTimerDuration?,)>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('home_fan_pick_title'.tr(),
                style: AppStyles.subsectionTitle(ctx)),
            const SizedBox(height: AppStyles.spacing12),
            OutlinedButton(
              key: const Key('fan_steady_on'),
              onPressed: () => Navigator.of(ctx).pop((null,)),
              child: Text('home_fan_steady_on'.tr()),
            ),
            const SizedBox(height: AppStyles.spacing8),
            Row(
              children: [
                for (final d in FanTimerDuration.values) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: Key('fan_timer_${d.minutes}'),
                      onPressed: () => Navigator.of(ctx).pop((d,)),
                      child: Text(d.labelKey.tr()),
                    ),
                  ),
                  if (d != FanTimerDuration.values.last)
                    const SizedBox(width: AppStyles.spacing8),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final duration = picked.$1;
  final sent = await sendCageCommand(
    context,
    ref,
    deviceId,
    CommandAction.fanOn,
    payload: duration?.payload,
  );
  // 타이머면 만료 시각에 완료 알림을 예약하고, '계속 켜기'면 기존 예약을
  // 내린다(기존 타이머 대체). 판단은 서비스 쪽 plan이 한다.
  if (sent) {
    await timerNotifs.onFanCommandSent(
      deviceId,
      CommandAction.fanOn.toWire(),
      duration == null ? null : duration.minutes * 60000,
    );
  }
  // '계속 켜기'(duration 없음)도 invalidate한다 — duration 없는 fan_on은
  // 진행 중이던 타이머를 대체(소멸)시키므로, 안 깨우면 옛 칩이 만료 시각까지
  // 가짜 카운트다운을 돈다. await 뒤라 mounted 재확인.
  if (context.mounted) ref.invalidate(runningTimersProvider);
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
    messenger.showSnackBar(
      SnackBar(content: Text('home_mist_sent'.tr(args: ['${duration.seconds}']))),
    );
  } catch (e, st) {
    debugPrint('[cage-control] mist failed: $e\n$st');
    messenger.showSnackBar(
      SnackBar(content: Text('home_mist_failed'.tr())),
    );
  }
}

// 분무 지속시간 선택 시트(openMistSheet)·mistDurationProvider는 2026-09-07
// 사용자 지시로 폐지 — 홈 분무 타일은 무조건 3초 분사(cage_control_grid).
// 예약 편집기의 분무 시간 선택(schedule_editor_sheet)은 별개로 유지된다.

/// LED 켜기/끄기 시트 — 보드 능력에 따라 밝기 슬라이더가 붙는다.
///
/// **밝기는 `Device.ledDimmable`(MOSFET 보드)일 때만** 보여준다. 릴레이 보드는
/// `brightness`를 무시하고 켜기만 하므로(2026-08-18 백엔드 회신 §2) 슬라이더를
/// 띄우면 아무 효과 없는 UI가 된다 — 2026-08-12에 그래서 걷어냈던 것이다.
/// 펌웨어가 아직 capabilities를 보고하지 않아 당분간은 전부 on/off로 보이고,
/// 보고가 붙거나 운영자가 DB를 갱신하면 그 기기만 슬라이더가 열린다.
///
/// 토글이 아니라 **켜기/끄기를 따로 고르게** 한다. `telemetry.led`가 생겨
/// (회신 §4) 현재 상태는 알 수 있지만, 구 펌웨어는 여전히 안 보내므로 모르는
/// 상태를 뒤집는 버튼은 두지 않는다.
Future<void> openLedSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId, {
  int? currentBrightness,
}) async {
  final device = ref
      .read(deviceListProvider)
      .valueOrNull
      ?.where((d) => d.id == deviceId)
      .firstOrNull;
  final dimmable = device?.ledDimmable ?? false;
  // 0 이하는 "꺼짐"이지 밝기가 아니다 — 시드로 쓰면 1%로 열린다.
  final seed = (currentBrightness ?? 0) > 0 ? currentBrightness! : 60;
  final choice = await showModalBottomSheet<_LedChoice>(
    context: context,
    builder: (ctx) => _LedSheet(dimmable: dimmable, initialBrightness: seed),
  );
  if (choice == null || !context.mounted) return;
  await sendCageCommand(
    context,
    ref,
    deviceId,
    choice.on ? CommandAction.ledOn : CommandAction.ledOff,
    // 릴레이 보드엔 brightness를 싣지 않는다 — 서버·펌웨어가 무시하긴 하지만
    // 실DB `led_*` 이력에 의미 없는 payload를 남기지 않는다.
    payload: choice.on && dimmable && choice.brightness != null
        ? {'brightness': choice.brightness}
        : null,
  );
}

class _LedChoice {
  const _LedChoice.on([this.brightness]) : on = true;
  const _LedChoice.off()
      : on = false,
        brightness = null;

  final bool on;
  final int? brightness;
}

class _LedSheet extends StatefulWidget {
  const _LedSheet({required this.dimmable, required this.initialBrightness});

  final bool dimmable;
  final int initialBrightness;

  @override
  State<_LedSheet> createState() => _LedSheetState();
}

class _LedSheetState extends State<_LedSheet> {
  late double _brightness =
      widget.initialBrightness.clamp(1, 100).toDouble();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('home_led_pick_title'.tr(),
                style: AppStyles.subsectionTitle(context)),
            const SizedBox(height: AppStyles.spacing12),
            if (widget.dimmable) ...[
              Row(
                children: [
                  Text('home_led_brightness'.tr(),
                      style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  Text('unit_percent_fmt'.tr(args: ['${_brightness.round()}']),
                      key: const Key('led_brightness_value'),
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              Slider(
                key: const Key('led_brightness_slider'),
                value: _brightness,
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: (v) => setState(() => _brightness = v),
              ),
              const SizedBox(height: AppStyles.spacing8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('led_on'),
                    onPressed: () => Navigator.of(context).pop(widget.dimmable
                        ? _LedChoice.on(_brightness.round())
                        : const _LedChoice.on()),
                    child: Text((widget.dimmable
                            ? 'home_led_apply_brightness'
                            : 'home_led_turn_on')
                        .tr()),
                  ),
                ),
                const SizedBox(width: AppStyles.spacing8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('led_off'),
                    onPressed: () =>
                        Navigator.of(context).pop(const _LedChoice.off()),
                    child: Text('home_led_turn_off'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
