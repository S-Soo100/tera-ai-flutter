import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../domain/redesign_management.dart';
import 'device_management_controller.dart';
import 'group_editor_screen.dart';
import 'widgets/management_widgets.dart';

class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen(
      {super.key, required this.kind, required this.itemId});
  final ManagementKind kind;
  final String itemId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(redesignGroupRepositoryProvider);
    return ref.watch(managementInventoryProvider).when(
        loading: () => const Scaffold(
            body: SafeArea(child: SkeletonCard(lineCount: 3, height: 200))),
        error: (_, __) => Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(managementInventoryProvider),
                    child: Text('management_load_retry'.tr())))),
        data: (inventory) {
          final item = inventory.item(ManagementKey(kind: kind, id: itemId));
          if (repo == null || item == null || kind == ManagementKind.pet) {
            return Scaffold(
                body: Center(child: Text('management_item_missing'.tr())));
          }
          return ProviderScope(
              key: ValueKey((repo, kind, itemId)),
              overrides: [
                deviceEditorControllerProvider
                    .overrideWith((ref) => DeviceEditorController(repo, item)),
              ],
              child: _DeviceDetailBody(item: item, inventory: inventory));
        });
  }
}

class _DeviceDetailBody extends ConsumerWidget {
  const _DeviceDetailBody({required this.item, required this.inventory});
  final ManagementItem item;
  final ManagementInventory inventory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(deviceEditorControllerProvider);
    final glass = context.glass;
    final dirty = draft.name != item.name;
    Future<void> leave() async {
      if (draft.saving) return;
      if (!dirty ||
          await managementConfirm(context, 'management_discard'.tr())) {
        if (context.mounted) context.pop();
      }
    }

    Future<void> finish(Future<bool> Function() action) async {
      if (await action() && context.mounted) {
        ref.read(managementMutationCompletedProvider)();
        context.pop();
      }
    }

    Future<void> groups() async {
      final chosen = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => ProviderScope(overrides: [
          _selectedDeviceGroupProvider.overrideWith((ref) => item.groupId),
        ], child: _DeviceGroupSettings(item: item, inventory: inventory)),
      ));
      if (chosen == null || !context.mounted) return;
      if (chosen == _removeGroupAction) {
        if (item.groupId != null &&
            await managementConfirm(context, 'management_remove_confirm'.tr(),
                action: 'management_remove'.tr()) &&
            context.mounted) {
          await finish(() => ref
              .read(deviceEditorControllerProvider.notifier)
              .removeFromGroup(item.groupId!));
        }
        return;
      }
      if (chosen == item.groupId) return;
      final target = chosen == 'new' ? null : inventory.group(chosen);
      if (item.groupId != null) {
        final accepted = await managementConfirm(
            context,
            'management_move_confirm'.tr(namedArgs: {
              'item': item.name,
              'group': inventory.group(item.groupId)?.name ??
                  'management_group'.tr(),
              'target': target?.name ?? 'management_new_group'.tr(),
            }),
            action: 'management_move'.tr());
        if (!accepted || !context.mounted) return;
      }
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) =>
              GroupEditorScreen(groupId: target?.id, initialMember: item.key)));
    }

    return PopScope(
        canPop: !dirty && !draft.saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Scaffold(
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      ManagementTopBar(
                          title: 'management_device'.tr(), onBack: leave),
                      Expanded(
                          child: ListView(
                              padding:
                                  const EdgeInsets.only(top: 16, bottom: 24),
                              children: [
                            ManagementLabel('management_device_name'.tr()),
                            const SizedBox(height: 12),
                            ManagementNameField(
                                initialName: draft.name,
                                enabled: !draft.saving,
                                errorKey: draft.nameErrorKey,
                                onChanged: (value) => ref
                                    .read(
                                        deviceEditorControllerProvider.notifier)
                                    .renameDraft(value)),
                            const SizedBox(height: 44),
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(children: [
                                  Row(children: [
                                    ManagementItemIcon(item.key.kind),
                                    const SizedBox(width: 12),
                                    Text('management_device_info'.tr(),
                                        style: managementStyle(context,
                                            weight: FontWeight.w600)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(item.hardwareId ?? '--',
                                            textAlign: TextAlign.right,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: managementStyle(context,
                                                weight: FontWeight.w600)))
                                  ]),
                                  const SizedBox(height: 24),
                                  Row(children: [
                                    ManagementSymbolBadge(
                                        'redesign_v2/power_settings_new'),
                                    const SizedBox(width: 12),
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('management_power'.tr(),
                                              style: managementStyle(context,
                                                  weight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text('management_power_on_label'.tr(),
                                              style: managementStyle(context,
                                                  size: 14,
                                                  color: glass.textTertiary)),
                                        ]),
                                    const Spacer(),
                                    Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                            color: glass.overlay,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Row(children: [
                                          for (final on in [true, false])
                                            InkWell(
                                                key: Key(on
                                                    ? 'management_power_on'
                                                    : 'management_power_off'),
                                                onTap:
                                                    () {}, // Explicit product contract: ON fixed, no command.
                                                child: Container(
                                                    width: 56,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                        border: on
                                                            ? Border(
                                                                right: BorderSide(
                                                                    color: glass
                                                                        .border))
                                                            : null),
                                                    child: Text(
                                                        (on
                                                                ? 'management_on'
                                                                : 'management_off')
                                                            .tr(),
                                                        style: managementStyle(
                                                            context))))
                                        ])),
                                  ]),
                                  const SizedBox(height: 24),
                                  Row(children: [
                                    ManagementSymbolBadge(
                                        'redesign_v2/workspaces'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(
                                            inventory
                                                    .group(item.groupId)
                                                    ?.name ??
                                                'management_ungrouped'.tr(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: managementStyle(context,
                                                weight: FontWeight.w600))),
                                    TextButton(
                                        style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 36),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap),
                                        onPressed: draft.saving ? null : groups,
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                  'management_group_setting'
                                                      .tr(),
                                                  style: managementStyle(
                                                      context,
                                                      weight: FontWeight.w600)),
                                              const SizedBox(width: 4),
                                              FigmaIcon.tinted(
                                                  FigmaIcons.arrowNext,
                                                  size: 18,
                                                  color: glass.textSecondary),
                                            ])),
                                  ]),
                                ])),
                            if (draft.errorKey != null)
                              Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(draft.errorKey!.tr(),
                                      key: const Key('management_save_error'),
                                      style: managementStyle(context,
                                          size: 14, color: glass.navSelected))),
                          ])),
                      ManagementButton(
                          label: (draft.saving
                                  ? 'management_saving'
                                  : 'management_done')
                              .tr(),
                          onPressed: draft.saving
                              ? null
                              : () => finish(() => ref
                                  .read(deviceEditorControllerProvider.notifier)
                                  .save(inventory))),
                      SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextButton(
                              onPressed: draft.saving
                                  ? null
                                  : () async {
                                      if (await managementConfirm(context,
                                              'management_delete_confirm'.tr(),
                                              action:
                                                  'management_delete'.tr()) &&
                                          context.mounted) {
                                        await finish(() => ref
                                            .read(deviceEditorControllerProvider
                                                .notifier)
                                            .unlink());
                                      }
                                    },
                              child: Text('management_delete_device'.tr(),
                                  style: managementStyle(context,
                                          size: 18,
                                          weight: FontWeight.w600,
                                          color: glass.navSelected)
                                      .copyWith(height: 28 / 18)))),
                      const SizedBox(height: 10),
                    ])))));
  }
}

const _removeGroupAction = '__remove_group__';
final _selectedDeviceGroupProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Membership controls live on the Figma group-settings page, not the device page.
class _DeviceGroupSettings extends ConsumerWidget {
  const _DeviceGroupSettings({required this.item, required this.inventory});
  final ManagementItem item;
  final ManagementInventory inventory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDeviceGroupProvider);
    final glass = context.glass;
    return Scaffold(
        body: SafeArea(
            child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        ManagementTopBar(
            title: 'management_group_setting'.tr(),
            onBack: () => Navigator.pop(context)),
        Expanded(
            child: ListView(padding: const EdgeInsets.only(top: 16), children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                ManagementItemIcon(item.key.kind),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(item.name,
                        style:
                            managementStyle(context, weight: FontWeight.w600))),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(item.hardwareId ?? '--',
                        textAlign: TextAlign.right,
                        style: managementStyle(context,
                            color: glass.textPrimary, weight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
              ])),
          const SizedBox(height: 28),
          for (final group in inventory.groups)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: glass.overlay,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ref
                        .read(_selectedDeviceGroupProvider.notifier)
                        .state = group.id,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    group.number == null
                                        ? 'management_group'.tr()
                                        : 'management_group_number'.tr(
                                            namedArgs: {
                                                'number': '${group.number}'
                                              }),
                                    style: managementStyle(context,
                                        color: glass.textTertiary)),
                                const SizedBox(height: 16),
                                Text(group.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: managementStyle(context,
                                        weight: FontWeight.w600)),
                              ])),
                          for (final kind in ManagementKind.values) ...[
                            const SizedBox(width: 8),
                            ManagementItemIcon(kind,
                                backgroundColor: inventory
                                        .members(group.id)
                                        .any((item) => item.key.kind == kind)
                                    ? glass.textSecondary
                                    : glass.textTertiary),
                          ],
                          const SizedBox(width: 8),
                          FigmaIcon.tinted(
                              selected == group.id
                                  ? 'redesign_v2/check_box_300'
                                  : 'redesign_v2/check_box_outline_blank_400',
                              size: 24,
                              color: selected == group.id
                                  ? glass.navSelected
                                  : glass.deviceOff),
                        ])),
                  ),
                )),
          Material(
              color: glass.overlay,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, 'new'),
                  child: SizedBox(
                      height: 52,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            FigmaIcon.tinted(FigmaIcons.add,
                                size: 24, color: glass.navSelected),
                            const SizedBox(width: 4),
                            Text('management_add_group'.tr(),
                                style: managementStyle(context,
                                        weight: FontWeight.w600,
                                        color: glass.navSelected)
                                    .copyWith(height: 28 / 16)),
                          ]))))),
        ])),
        ManagementButton(
            label: 'management_done'.tr(),
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected)),
        if (item.groupId != null)
          SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () => Navigator.pop(context, _removeGroupAction),
                child: Text('management_remove_group'.tr(),
                    style: managementStyle(context,
                            size: 18,
                            color: glass.navSelected,
                            weight: FontWeight.w600)
                        .copyWith(height: 28 / 18)),
              )),
        const SizedBox(height: 10),
      ]),
    )));
  }
}
