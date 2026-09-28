import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/viva_modal.dart';
import '../../domain/camera_health.dart';
import '../camera_health_controllers.dart';
import '../my_cage_providers.dart';
import 'management_widgets.dart';

/// 카메라 상세 상단 Wi-Fi 약함 배너(요청서 §3, Figma 밖). 평소엔 신호 세기를
/// 보이지 않고, 약한 값이 연속될 때만 뜬다. 구 펌웨어(`rssi` 없음)는 영영 안 뜬다.
class WeakWifiBannerView extends ConsumerWidget {
  const WeakWifiBannerView({super.key, required this.cameraUuid});
  final String cameraUuid;

  static const bannerKey = Key('camera_weak_wifi_banner');
  static const closeKey = Key('camera_weak_wifi_close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(weakWifiBannerProvider(cameraUuid))) {
      return const SizedBox.shrink();
    }
    final glass = context.glass;
    return Padding(
        key: bannerKey,
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            decoration: BoxDecoration(
                color: glass.overlay, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              FigmaIcon.tinted('redesign_v2/wifi-1',
                  size: 24, color: glass.signalWarn),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('camera_weak_wifi'.tr(),
                      style: managementStyle(context, size: 14))),
              TextButton(
                  key: closeKey,
                  onPressed: () => ref
                      .read(weakWifiBannerProvider(cameraUuid).notifier)
                      .dismiss(),
                  child: Text('camera_weak_wifi_close'.tr(),
                      style: managementStyle(context,
                          size: 14, weight: FontWeight.w600))),
            ])));
  }
}

/// 카메라 상세 "카메라 재시작" 줄(요청서 §2, Figma 밖). 켜져 있고 재시작을 아는
/// 펌웨어(0.2.0+)일 때만 보인다 — 구 펌웨어는 눌러도 반응이 없어 **숨긴다**
/// (비활성 표시 X). 재시작 중엔 오프라인이 돼도 결과까지 남겨 둔다.
class CameraRebootRow extends ConsumerWidget {
  const CameraRebootRow({super.key, required this.cameraUuid});
  final String cameraUuid;

  static const rowKey = Key('camera_reboot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref
        .watch(camerasProvider)
        .valueOrNull
        ?.where((c) => c.id == cameraUuid)
        .firstOrNull;
    final reboot = ref.watch(cameraRebootProvider(cameraUuid));
    ref.listen(cameraRebootProvider(cameraUuid), (previous, next) {
      if (next.round == previous?.round || next.outcome == null) return;
      if (next.outcome == CameraRebootOutcome.done) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('camera_reboot_done'.tr())));
      } else {
        showVivaModal(context,
            message: 'camera_reboot_timeout'.tr(),
            confirmLabel: 'common_confirm'.tr());
      }
    });
    final capable = camera != null &&
        camera.isOnline &&
        isRebootCapableFirmware(camera.firmwareVer);
    if (!capable && !reboot.rebooting) return const SizedBox.shrink();
    final busy = reboot.sending ||
        reboot.rebooting ||
        reboot.coolingDown(DateTime.now());
    final glass = context.glass;

    Future<void> tap() async {
      final ok = await showVivaModal(context,
          message: 'camera_reboot_confirm'.tr(),
          cancelLabel: 'common_cancel'.tr(),
          confirmLabel: 'camera_reboot_ok'.tr(),
          confirmKey: const Key('camera_reboot_ok'));
      if (!ok || !context.mounted) return;
      final result =
          await ref.read(cameraRebootProvider(cameraUuid).notifier).request();
      if (!context.mounted) return;
      final message = switch (result) {
        CameraRebootRequest.published => null,
        CameraRebootRequest.notPublished => 'camera_reboot_retry_later',
        CameraRebootRequest.notFound => 'camera_reboot_not_found',
        CameraRebootRequest.failed => 'camera_reboot_failed',
      };
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message.tr())));
      }
    }

    return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: InkWell(
            key: rowKey,
            onTap: busy ? null : tap,
            child: Row(children: [
              ManagementSymbolBadge('redesign_v2/restart_alt'),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('camera_reboot'.tr(),
                      style: managementStyle(context,
                          weight: FontWeight.w600,
                          color: busy ? glass.textTertiary : null))),
              if (reboot.sending || reboot.rebooting)
                Text('camera_reboot_progress'.tr(),
                    key: const Key('camera_reboot_progress'),
                    style: managementStyle(context,
                        weight: FontWeight.w600, color: glass.textTertiary))
              else
                FigmaIcon.tinted(FigmaIcons.arrowNext,
                    size: 18,
                    color: busy ? glass.textTertiary : glass.textSecondary),
            ])));
  }
}
