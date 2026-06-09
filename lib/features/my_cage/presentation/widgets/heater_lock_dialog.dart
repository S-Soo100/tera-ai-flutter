import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/device_command.dart';
import '../supabase_module_providers.dart';

/// 히터 안전 잠금 해제 2단계 확인 다이얼로그.
///
/// [showHeaterLockDialog] — 성공 시 true, 취소/실패 시 false 반환.
/// [deviceId] — `currentDeviceProvider`에서 가져온 device.id 필수.
Future<bool> showHeaterLockDialog(
  BuildContext context,
  WidgetRef ref, {
  required String deviceId,
}) async {
  final step1 = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _HeaterLockStep1Dialog(),
  );

  if (step1 != true) return false;
  if (!context.mounted) return false;

  final step2 = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _HeaterLockStep2Dialog(),
  );

  if (step2 != true) return false;
  if (!context.mounted) return false;

  try {
    await ref
        .read(moduleCommandSenderProvider.notifier)
        .send(deviceId, CommandAction.heaterClear);

    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('heater_unlocked_toast'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('module_action_error'.tr()),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    return false;
  }
}

// ── 1단계 다이얼로그 ──────────────────────────────────────────────────────────

class _HeaterLockStep1Dialog extends StatelessWidget {
  const _HeaterLockStep1Dialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFFF8F00)),
          const SizedBox(width: 8),
          Text('heater_lock_title'.tr()),
        ],
      ),
      content: Text('heater_lock_body'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('heater_lock_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8F00),
            foregroundColor: Colors.white,
          ),
          child: Text('heater_lock_unlock'.tr()),
        ),
      ],
    );
  }
}

// ── 2단계 다이얼로그 ──────────────────────────────────────────────────────────

class _HeaterLockStep2Dialog extends StatelessWidget {
  const _HeaterLockStep2Dialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text('heater_unlock_confirm_title'.tr())),
        ],
      ),
      content: Text('heater_unlock_confirm_body'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('heater_lock_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('heater_unlock_confirm_yes'.tr()),
        ),
      ],
    );
  }
}
