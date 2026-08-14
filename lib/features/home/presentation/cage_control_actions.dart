/// 사육장 액추에이터 제어 동작 모음.
///
/// 히터는 과열 시 개체 폐사로 이어지는 유일한 액추에이터다. 그래서 명령과
/// **안전 확인 플로우를 위젯 밖 여기 한 곳에** 둔다.
///
/// 지금 진입점은 서브탭의 2x2 그리드(`QuickControlGrid`) 하나뿐이지만, 한때
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

import '../../../core/theme/app_styles.dart';
import '../../my_cage/domain/device_command.dart';
import '../../my_cage/domain/actuator_state.dart';
import '../../my_cage/domain/telemetry_reading.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/widgets/heater_lock_dialog.dart';
import '../domain/fan_timer_duration.dart';
import '../domain/mist_duration.dart';
import '../domain/mist_lock.dart';
import 'widgets/running_timer_chip.dart';

/// 분무 중복 클릭 락. **기기별로 분리한다** — 전역이면 A 사육장에서 분무한 뒤
/// B 사육장으로 스와이프해도 B의 버튼이 잠긴다.
final mistLockProvider = StateProvider.family<MistLock, String>(
  (ref, deviceId) => const MistLock(lockedUntil: null),
);

/// 마지막으로 고른 분무 시간. 기기별로 나눌 이유가 없다(사용자 취향).
final mistDurationProvider =
    StateProvider<MistDuration>((ref) => MistDuration.defaultValue);

/// 명령 1건 발행. **실패를 삼키지 않는다.**
///
/// onTap은 VoidCallback이라 여기서 던지면 unhandled async error로 콘솔에만
/// 남고 사용자는 "눌렀는데 아무 일도 안 일어남"을 기기 고장으로 오해한다.
/// 그래서 여기서 잡아 토스트로 알린다.
Future<void> sendCageCommand(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  CommandAction action, {
  Map<String, dynamic>? payload,
}) async {
  try {
    await ref
        .read(moduleCommandSenderProvider.notifier)
        .send(deviceId, action, payload: payload);
  } catch (e, st) {
    debugPrint('[cage-control] $action failed: $e\n$st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('module_command_failed'.tr())),
    );
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
  final isOn = telemetry?.fan == ActuatorState.on;
  if (isOn) {
    await sendCageCommand(context, ref, deviceId, CommandAction.fanOff);
    // 타이머 가동 중이었다면 취소된 것 — 칩을 깨워 내린다.
    ref.invalidate(runningTimersProvider);
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
  await sendCageCommand(
    context,
    ref,
    deviceId,
    CommandAction.fanOn,
    payload: duration?.payload,
  );
  if (duration != null) ref.invalidate(runningTimersProvider);
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
  try {
    await ref.read(moduleCommandSenderProvider.notifier).send(
          deviceId,
          CommandAction.mist,
          payload: duration.payload,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('home_mist_sent'.tr(args: ['${duration.seconds}']))),
    );
  } catch (e, st) {
    debugPrint('[cage-control] mist failed: $e\n$st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('home_mist_failed'.tr())),
    );
  }
}

/// 분무 지속시간 선택 시트. 고른 즉시 분사한다.
///
/// 시트를 한 겹 두는 대신 **고르는 행위가 곧 실행**이다. "고르고 → 확인" 2탭을
/// 요구하면 하루에도 몇 번씩 누르는 동작이 무거워진다.
Future<void> openMistSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) async {
  final picked = await showModalBottomSheet<MistDuration>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'home_mist_pick_title'.tr(),
              style: AppStyles.subsectionTitle(ctx),
            ),
            const SizedBox(height: AppStyles.spacing12),
            Row(
              children: [
                for (final d in MistDuration.values) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: Key('mist_duration_${d.seconds}'),
                      onPressed: () => Navigator.of(ctx).pop(d),
                      child: Text('home_mist_seconds'
                          .tr(args: ['${d.seconds}'])),
                    ),
                  ),
                  if (d != MistDuration.values.last)
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
  ref.read(mistDurationProvider.notifier).state = picked;
  await mistOnce(context, ref, deviceId, picked);
}

/// LED 켜기/끄기 시트.
///
/// **밝기 조절은 없다.** 현 보드의 LED는 PWM이 아니라 단순 on/off 릴레이라
/// `brightness`가 물리적으로 반영되지 않는다(백엔드 회신 2026-08-12). 실제로
/// 실DB의 `led_*` 236건이 전부 `payload = null`이었고, 그동안 앱 슬라이더는
/// 아무 효과 없이 떠 있었다. PRD §4.2.2의 0~100%는 하드웨어 PWM이 생기면
/// 되살린다.
///
/// 토글이 아니라 **켜기/끄기를 따로 고르게** 한다. 기기가 LED 상태를 telemetry로
/// 올려주지 않아 앱이 지금 켜져 있는지 모르는데, 모르는 상태를 뒤집는 버튼은
/// 어느 쪽으로 갈지 사용자도 모른다.
Future<void> openLedSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) async {
  final on = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('home_led_pick_title'.tr(),
                style: AppStyles.subsectionTitle(ctx)),
            const SizedBox(height: AppStyles.spacing12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('led_on'),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('home_led_turn_on'.tr()),
                  ),
                ),
                const SizedBox(width: AppStyles.spacing8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('led_off'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('home_led_turn_off'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (on == null || !context.mounted) return;
  await sendCageCommand(
    context,
    ref,
    deviceId,
    on ? CommandAction.ledOn : CommandAction.ledOff,
  );
}
