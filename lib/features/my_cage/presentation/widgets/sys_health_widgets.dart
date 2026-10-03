import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/viva_modal.dart';
import '../../domain/pair_target_kind.dart';
import '../../domain/sys_health.dart';
import '../my_cage_providers.dart';
import '../sys_health_controllers.dart';
import 'management_widgets.dart';

String _byKind(PairTargetKind kind, String suffix) =>
    '${kind == PairTargetKind.camera ? 'camera' : 'device'}_$suffix';

/// 기기 상세 상단 Wi-Fi 약함 배너(카메라·사육장, Figma 밖). 평소엔 신호 세기를
/// 보이지 않고, 약한 값이 약 1분 이어질 때만 뜬다. 구 펌웨어는 영영 안 뜬다.
class WeakWifiBannerView extends ConsumerWidget {
  const WeakWifiBannerView({super.key, required this.target});
  final SysTarget target;

  static const bannerKey = Key('weak_wifi_banner');
  static const closeKey = Key('weak_wifi_close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(weakWifiBannerProvider(target))) {
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
                  child: Text(_byKind(target.$1, 'weak_wifi').tr(),
                      style: managementStyle(context, size: 14))),
              TextButton(
                  key: closeKey,
                  onPressed: () => ref
                      .read(weakWifiBannerProvider(target).notifier)
                      .dismiss(),
                  child: Text('weak_wifi_close'.tr(),
                      style: managementStyle(context,
                          size: 14, weight: FontWeight.w600))),
            ])));
  }
}

/// 기기 상세 "재시작" 줄(카메라·사육장, Figma 밖). 켜져 있고 재시작을 아는
/// 펌웨어일 때만 보인다 — 카메라는 `firmware_ver` ≥ 0.2.0, 사육장은
/// `sys_state != null`. 조건이 안 맞으면 **숨긴다**(비활성 표시 X). 재시작 중엔
/// 오프라인이 돼도 결과까지 남겨 둔다.
class RebootRow extends ConsumerWidget {
  const RebootRow({super.key, required this.target});
  final SysTarget target;

  static const rowKey = Key('reboot_row');

  bool _capable(WidgetRef ref) {
    final (kind, id) = target;
    if (kind == PairTargetKind.camera) {
      final camera = ref
          .watch(camerasProvider)
          .valueOrNull
          ?.where((c) => c.id == id)
          .firstOrNull;
      return cameraRebootCapable(camera);
    }
    final health = ref.watch(sysHealthProvider(target)).valueOrNull;
    return health != null && health.present && health.isOnline == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = target.$1;
    final reboot = ref.watch(rebootProvider(target));
    ref.listen(rebootProvider(target), (previous, next) {
      final outcome = next.outcome;
      if (next.round == previous?.round || outcome == null) return;
      void snack(String key) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(key.tr())));
      void modal(String key) => showVivaModal(context,
          message: key.tr(), confirmLabel: 'common_confirm'.tr());
      switch (outcome) {
        case RebootOutcome.done:
          snack(kind == PairTargetKind.camera
              ? 'camera_reboot_done'
              : 'reboot_done');
        case RebootOutcome.timedOut:
          modal(_byKind(kind, 'reboot_timeout'));
        case RebootOutcome.noAck:
          snack('device_reboot_no_ack');
        case RebootOutcome.unsupported:
          modal('device_reboot_unsupported');
        case RebootOutcome.failed:
          snack('device_reboot_failed_result');
      }
    });
    if (!_capable(ref) && !reboot.rebooting) return const SizedBox.shrink();
    final busy = reboot.sending ||
        reboot.rebooting ||
        reboot.coolingDown(DateTime.now());
    final glass = context.glass;

    Future<void> tap() => confirmAndRequestReboot(context, ref, target);

    return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: InkWell(
            key: rowKey,
            onTap: busy ? null : tap,
            child: Row(children: [
              ManagementSymbolBadge('redesign_v2/restart_alt'),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(_byKind(kind, 'reboot').tr(),
                      style: managementStyle(context,
                          weight: FontWeight.w600,
                          color: busy ? glass.textTertiary : null))),
              if (reboot.sending || reboot.rebooting)
                Text('reboot_progress'.tr(),
                    key: const Key('reboot_progress'),
                    style: managementStyle(context,
                        weight: FontWeight.w600, color: glass.textTertiary))
              else
                FigmaIcon.tinted(FigmaIcons.arrowNext,
                    size: 18,
                    color: busy ? glass.textTertiary : glass.textSecondary),
            ])));
  }
}

/// 재시작 확인창 → 요청 → 요청 결과 안내(스낵바). 기기 상세 "재시작" 줄과
/// 라이브 실패 화면의 [카메라 재시작]이 같이 쓴다. 재시작 뒤 결과(완료·무소식)는
/// 여기서 안내하지 않는다 — 상세는 줄이, 라이브는 면이 알린다.
Future<void> confirmAndRequestReboot(
    BuildContext context, WidgetRef ref, SysTarget target) async {
  final kind = target.$1;
  final confirm = [
    _byKind(kind, 'reboot_confirm').tr(),
    if (kind == PairTargetKind.device && kDeviceRebootScheduleNote)
      'device_reboot_schedule_note'.tr(),
  ].join('\n');
  final ok = await showVivaModal(context,
      message: confirm,
      cancelLabel: 'common_cancel'.tr(),
      confirmLabel: 'reboot_ok'.tr(),
      confirmKey: const Key('reboot_ok'));
  if (!ok || !context.mounted) return;
  final result = await ref.read(rebootProvider(target).notifier).request();
  if (!context.mounted) return;
  final message = switch (result) {
    RebootRequest.published => null,
    RebootRequest.notPublished => 'reboot_retry_later',
    RebootRequest.notFound => _byKind(kind, 'reboot_not_found'),
    RebootRequest.failed => 'reboot_failed',
  };
  if (message != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.tr())));
  }
}
