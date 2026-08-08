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
import '../../my_cage/domain/telemetry_reading.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/widgets/heater_lock_dialog.dart';
import '../domain/mist_lock.dart';

/// 분무 중복 클릭 락. **기기별로 분리한다** — 전역이면 A 사육장에서 분무한 뒤
/// B 사육장으로 스와이프해도 B의 버튼이 잠긴다.
final mistLockProvider = StateProvider.family<MistLock, String>(
  (ref, deviceId) => const MistLock(lockedUntil: null),
);

/// LED 밝기(0~100). BE3 전까지 펌웨어가 payload를 무시할 수 있다.
final ledBrightnessProvider = StateProvider<int>((ref) => 70);

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

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('module_heater_confirm_title'.tr()),
      content: Text('module_heater_confirm_body'.tr()),
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

  await sendCageCommand(context, ref, deviceId, CommandAction.heaterToggle);
}

/// 1회 즉시 분사.
///
/// BE2(`relay_pulse`)가 없으므로 `relay_toggle`을 **1회만** 보낸다.
/// 앱에서 ON→지연 OFF로 펄스를 흉내내면 앱이 백그라운드로 가는 순간 펌프가
/// 계속 돈다 — 절대 하지 않는다.
Future<void> mistOnce(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
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
    await ref
        .read(moduleCommandSenderProvider.notifier)
        .send(deviceId, CommandAction.relayToggle);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('home_mist_sent'.tr())),
    );
  } catch (e, st) {
    debugPrint('[cage-control] mist failed: $e\n$st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('home_mist_failed'.tr())),
    );
  }
}

/// LED 밝기 선택 시트를 열고 결과를 전송한다.
Future<void> openBrightnessSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) async {
  final picked = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) {
      var v = ref.read(ledBrightnessProvider).toDouble();
      return StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppStyles.spacing16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('home_led_brightness'.tr(args: ['${v.round()}'])),
                Slider(
                  value: v,
                  max: 100,
                  divisions: 20,
                  onChanged: (n) => setLocal(() => v = n),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(v.round()),
                  child: Text('common_confirm'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (picked == null || !context.mounted) return;
  ref.read(ledBrightnessProvider.notifier).state = picked;
  await sendCageCommand(
    context,
    ref,
    deviceId,
    picked == 0 ? CommandAction.ledOff : CommandAction.ledOn,
    payload: {'brightness': picked},
  );
}
