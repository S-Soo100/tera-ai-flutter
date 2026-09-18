import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/push_messaging_service.dart';
import 'push_providers.dart';

// 로그인 직후 일괄 설명 시트(PushPermissionPrompt)는 2026-09-18 제거 — Figma
// 권한 요청(1179:4464)대로 맥락 프리팝업(push_pre_popup.dart)이 대신한다.

class PushPermissionBanner extends ConsumerWidget {
  const PushPermissionBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushPermissionProvider);
    if (permission == PushPermission.authorized ||
        permission == PushPermission.unavailable) {
      return const SizedBox.shrink();
    }
    final busy = ref.watch(pushPermissionBusyProvider);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('push_permission_banner'.tr()),
        TextButton(
            onPressed: busy
                ? null
                : () async {
                    final busyNotifier =
                        ref.read(pushPermissionBusyProvider.notifier);
                    final controller =
                        ref.read(pushLifecycleControllerProvider);
                    busyNotifier.state = true;
                    try {
                      await controller.requestPermission(retry: true);
                    } finally {
                      busyNotifier.state = false;
                    }
                  },
            child: Text('push_enable'.tr())),
      ]),
    );
  }
}
