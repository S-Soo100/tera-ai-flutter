import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/redesign_management.dart';
import 'device_management_controller.dart';
import 'widgets/management_widgets.dart';

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(managementInventoryProvider);
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(children: [
                  ManagementTopBar(
                      title: 'management_title'.tr(),
                      close: true,
                      onBack: () => context.pop()),
                  Expanded(
                      child: async.when(
                          loading: () =>
                              const SkeletonCard(lineCount: 4, height: 200),
                          error: (_, __) => Center(
                              child: TextButton(
                                  onPressed: () => ref
                                      .invalidate(managementInventoryProvider),
                                  child: Text('management_load_retry'.tr()))),
                          data: (inventory) => ListView(
                                  padding: const EdgeInsets.only(
                                      top: 16, bottom: 24),
                                  children: [
                                    ManagementLabel('management_groups'.tr()),
                                    const SizedBox(height: 12),
                                    if (inventory.groups.isEmpty)
                                      Padding(
                                          padding: const EdgeInsets.all(16),
                                          child:
                                              Text('management_no_groups'.tr()))
                                    else
                                      for (final group in inventory.groups)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: ManagementGroupCard(
                                                group: group,
                                                members:
                                                    inventory.members(group.id),
                                                onTap: () => context.push(
                                                    '/groups/${group.id}'))),
                                    const SizedBox(height: 20),
                                    ManagementLabel(
                                        'management_ungrouped'.tr()),
                                    const SizedBox(height: 12),
                                    if (inventory.ungrouped.isEmpty)
                                      Padding(
                                          padding: const EdgeInsets.all(16),
                                          child:
                                              Text('management_no_items'.tr()))
                                    else
                                      for (final item in inventory.ungrouped)
                                        ManagementItemRow(
                                            item: item,
                                            onTap: () => context.push(item
                                                        .key.kind ==
                                                    ManagementKind.pet
                                                ? '/my-pets/${item.key.id}'
                                                : '/devices/${item.key.kind.name}/${item.key.id}')),
                                  ]))),
                  if (async.asData?.value case final inventory?) ...[
                    if (inventory.isEmpty)
                      ManagementButton(
                          key: const Key('management_add_device'),
                          label: 'management_add_device'.tr(),
                          red: true,
                          onPressed: () => context.push('/devices/add'))
                    else if (inventory.canAddGroup)
                      ManagementButton(
                          key: const Key('management_add_group'),
                          label: 'management_add_group'.tr(),
                          red: true,
                          onPressed: () => context.push('/groups/new')),
                    SizedBox(
                        height: (100 - MediaQuery.paddingOf(context).bottom)
                            .clamp(16, 100)),
                  ],
                ]))));
  }
}
