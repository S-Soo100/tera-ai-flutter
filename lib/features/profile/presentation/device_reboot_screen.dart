import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_cage/domain/pair_target_kind.dart';
import '../../my_cage/domain/redesign_management.dart';
import '../../my_cage/domain/sys_health.dart';
import '../../my_cage/presentation/device_management_controller.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../my_cage/presentation/sys_health_controllers.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../../my_cage/presentation/widgets/sys_health_widgets.dart';
import 'widgets/my_page_widgets.dart';

/// 마이페이지 → 사육장 기기 재시작(Figma 밖, 2026-10-04 사용자 요청 "만일을
/// 위한 것"). 라우트 `/profile/device-reboot`.
///
/// 기기 상세의 "재시작" 줄과 같은 흐름(`rebootProvider`·확인창·결과 안내)을
/// 쓰고, 진입점만 하나 더 둔다. 상세는 못 하는 기기에서 줄을 숨기지만 여기는
/// 비상용 목록이라 **모든 사육장 기기를 보여 주고 못 하는 이유를 적는다**.
/// 카메라는 라이브 실패 화면·기기 상세에 이미 있어 넣지 않는다.
class DeviceRebootScreen extends ConsumerWidget {
  const DeviceRebootScreen({super.key});

  static const emptyKey = Key('device_reboot_list_empty');
  static Key rowKey(String id) => Key('device_reboot_row_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final inventory = ref.watch(managementInventoryProvider);
    return MyPageScaffold(
      title: 'mypage_device_reboot_title'.tr(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Text('device_reboot_list_intro'.tr(),
                style: managementStyle(context,
                    size: 14, color: glass.textTertiary))),
        inventory.when(
          skipLoadingOnReload: true,
          loading: () => const SkeletonLoading(
              width: double.infinity, height: 64, borderRadius: 12),
          error: (_, __) => _Message('device_reboot_list_error'.tr()),
          data: (inv) {
            final devices = [
              for (final item in inv.items)
                if (item.key.kind == ManagementKind.device) item
            ];
            if (devices.isEmpty) {
              return _Message('device_reboot_list_empty'.tr(), key: emptyKey);
            }
            return Column(children: [
              for (final (i, item) in devices.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _DeviceRebootRow(
                    item: item, groupName: inv.group(item.groupId)?.name),
              ],
            ]);
          },
        ),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(text,
          textAlign: TextAlign.center,
          style: managementStyle(context, color: context.glass.textTertiary)));
}

/// 기기 한 대 — 상태를 부제로, 할 수 있을 때만 누를 수 있다.
///
/// 제목은 "세트 이름 · 기기 이름"(2026-10-08 사용자 요청 — "사육장 1·2"만으론
/// 어느 사육장인지 구분이 안 됐다). 세트가 없으면 기기 이름만.
class _DeviceRebootRow extends ConsumerWidget {
  const _DeviceRebootRow({required this.item, this.groupName});
  final ManagementItem item;
  final String? groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SysTarget target = (PairTargetKind.device, item.key.id);
    final health = ref.watch(sysHealthProvider(target));
    final reboot = ref.watch(rebootProvider(target));
    listenRebootOutcome(context, ref, target);

    final h = health.valueOrNull;
    // 직결 조회 실패면 is_online이 비어 온다 — 목록 값으로 보충한다.
    final online = h?.isOnline ?? item.isOnline;
    final inProgress = reboot.sending || reboot.rebooting;
    final String status;
    var enabled = false;
    if (inProgress) {
      status = reboot.slow
          ? 'crecam_live_rebooting_slow'.tr()
          : 'reboot_progress'.tr();
    } else if (h == null) {
      status = 'device_reboot_status_checking'.tr();
    } else if (online != true) {
      status = 'device_reboot_status_offline'.tr();
    } else if (!h.present) {
      status = 'device_reboot_status_old_firmware'.tr();
    } else if (reboot.coolingDown(DateTime.now())) {
      status = 'live_reboot_wait'.tr();
    } else {
      status = 'device_reboot_status_ready'.tr();
      enabled = true;
    }

    return Opacity(
        opacity: enabled || inProgress ? 1 : 0.6,
        child: MyPageRow(
            key: DeviceRebootScreen.rowKey(item.key.id),
            title: groupName == null || groupName!.isEmpty
                ? item.name
                : '$groupName · ${item.name}',
            subtitle: status,
            icon: FigmaIcon.tinted('redesign_v2/restart_alt',
                size: 24, color: ManagementColors.buttonForeground(context)),
            showArrow: enabled,
            onTap: enabled
                ? () => confirmAndRequestReboot(context, ref, target)
                : null));
  }
}
