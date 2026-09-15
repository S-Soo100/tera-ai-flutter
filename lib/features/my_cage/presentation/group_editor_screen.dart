import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/redesign_management.dart';
import 'device_management_controller.dart';
import 'widgets/management_widgets.dart';

class GroupEditorScreen extends ConsumerWidget {
  const GroupEditorScreen(
      {super.key,
      this.groupId,
      this.initialMember,
      this.selectMembers = false});
  final bool selectMembers;
  final String? groupId;

  /// Only used after the device membership selector confirmed any move.
  final ManagementKey? initialMember;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(redesignGroupRepositoryProvider);
    final async = ref.watch(managementInventoryProvider);
    return async.when(
        loading: () => const Scaffold(
            body: SafeArea(child: SkeletonCard(lineCount: 3, height: 200))),
        error: (_, __) => Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(managementInventoryProvider),
                    child: Text('management_load_retry'.tr())))),
        data: (inventory) {
          if (repo == null ||
              (groupId != null && inventory.group(groupId) == null)) {
            return Scaffold(
                body: Center(child: Text('management_item_missing'.tr())));
          }
          var draft = groupId == null
              ? GroupEditDraft(
                  useDefaultName: true,
                  name: nextManagementName('management_default_group'.tr(),
                      inventory.groups.map((g) => g.name)))
              : GroupEditDraft.existing(inventory.group(groupId)!, inventory);
          final member =
              initialMember == null ? null : inventory.item(initialMember!);
          if (member != null && !draft.members.contains(member.key)) {
            draft = draft.select(member);
          }
          if (selectMembers) draft = draft.copy(step: GroupEditorStep.members);
          final initial = draft;
          return ProviderScope(
              key: ValueKey((repo, groupId, initialMember)),
              overrides: [
                groupEditorControllerProvider.overrideWith(
                    (ref) => GroupEditorController(repo, initial)),
              ],
              child: _GroupEditorBody(inventory: inventory, initial: initial));
        });
  }
}

class _GroupEditorBody extends ConsumerWidget {
  const _GroupEditorBody({required this.inventory, required this.initial});
  final ManagementInventory inventory;
  final GroupEditDraft initial;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(groupEditorControllerProvider);
    final dirty = draft.name != initial.name ||
        draft.members.length != initial.members.length ||
        !draft.members.containsAll(initial.members);
    Future<void> leave() async {
      if (draft.saving) return;
      if (draft.step == GroupEditorStep.members) {
        ref.read(groupEditorControllerProvider.notifier).step(
            initial.groupId == null
                ? GroupEditorStep.name
                : GroupEditorStep.review);
        return;
      }
      if (!dirty ||
          await managementConfirm(context, 'management_discard'.tr())) {
        if (context.mounted) context.pop();
      }
    }

    Future<void> select(ManagementItem item) async {
      final controller = ref.read(groupEditorControllerProvider.notifier);
      if (!draft.members.contains(item.key) &&
          draft.requiresMoveConfirmation(item)) {
        final confirmed = await managementConfirm(
            context,
            'management_move_confirm'.tr(namedArgs: {
              'item': item.name,
              'group': inventory.group(item.groupId)?.name ??
                  'management_group'.tr(),
              'target': draft.name,
            }),
            action: 'management_move'.tr());
        if (!confirmed || !context.mounted) return;
      }
      controller.select(item);
    }

    Future<void> finish() async {
      // Let PopScope observe the committed state before leaving a dirty editor.
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      final refresh = ref.read(managementMutationCompletedProvider);
      context.pop();
      refresh();
    }

    Future<void> deleteGroup() async {
      if (draft.saving) return;
      final confirmed = await managementConfirm(
          context, 'management_delete_group_confirm'.tr(),
          action: 'management_delete'.tr());
      if (!confirmed || !context.mounted) return;
      if (await ref
          .read(groupEditorControllerProvider.notifier)
          .deleteGroup()) {
        await finish();
      }
    }

    Future<void> action() async {
      final controller = ref.read(groupEditorControllerProvider.notifier);
      switch (draft.step) {
        case GroupEditorStep.name:
          if (controller.validateName(inventory)) {
            controller.step(GroupEditorStep.members);
          }
        case GroupEditorStep.members:
          if (draft.members.isNotEmpty) controller.step(GroupEditorStep.review);
        case GroupEditorStep.review:
          if (await controller.save(inventory) && context.mounted) {
            await finish();
          }
      }
    }

    final button = switch (draft.step) {
      GroupEditorStep.name => 'management_choose_members',
      GroupEditorStep.members => 'management_select',
      GroupEditorStep.review =>
        draft.groupId == null ? 'management_create_group' : 'management_done',
    };
    final floatingSelection = draft.step == GroupEditorStep.members;
    final buttonBottom =
        (100 - MediaQuery.paddingOf(context).bottom).clamp(16.0, 100.0);
    final nextButton = ManagementButton(
        key: const Key('management_group_next'),
        label: (draft.saving ? 'management_saving' : button).tr(),
        onPressed: draft.saving ||
                (draft.step != GroupEditorStep.members &&
                    draft.nameErrorKey != null) ||
                (draft.step == GroupEditorStep.members && draft.members.isEmpty)
            ? null
            : action);
    return PopScope(
        canPop: draft.finished || (!dirty && !draft.saving),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Scaffold(
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      ManagementTopBar(
                          title: 'management_group'.tr(), onBack: leave),
                      Expanded(
                          child: Stack(fit: StackFit.expand, children: [
                        ListView(
                            padding: EdgeInsets.only(
                                top: 16,
                                bottom: floatingSelection
                                    ? buttonBottom + 56 + 24
                                    : 24),
                            children: [
                              if (draft.step == GroupEditorStep.name) ...[
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('management_name_heading'.tr(),
                                        style: managementStyle(context,
                                            size: 18,
                                            weight: FontWeight.w600))),
                                const SizedBox(height: 8),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('management_name_hint'.tr(),
                                        style: managementStyle(context,
                                            size: 14,
                                            color:
                                                context.glass.bodySecondary))),
                                const SizedBox(height: 16),
                              ] else if (draft.step ==
                                  GroupEditorStep.review) ...[
                                ManagementLabel('management_group_name'.tr()),
                                const SizedBox(height: 12),
                              ],
                              if (draft.step != GroupEditorStep.members)
                                ManagementNameField(
                                    initialName: draft.name,
                                    enabled: !draft.saving,
                                    errorBelowField: true,
                                    errorKey: draft.nameErrorKey ==
                                            'management_name_duplicate'
                                        ? 'management_group_name_duplicate'
                                        : draft.nameErrorKey,
                                    onChanged: (value) {
                                      final controller = ref.read(
                                          groupEditorControllerProvider
                                              .notifier);
                                      final revalidate =
                                          draft.nameErrorKey != null;
                                      controller.name(value);
                                      if (revalidate) {
                                        controller.validateName(inventory);
                                      }
                                    }),
                              if (draft.step == GroupEditorStep.members) ...[
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(draft.name,
                                        style: managementStyle(context,
                                            size: 18,
                                            weight: FontWeight.w600))),
                                const SizedBox(height: 8),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('management_member_hint'.tr(),
                                        style: managementStyle(context,
                                            size: 14,
                                            color:
                                                context.glass.bodySecondary))),
                                const SizedBox(height: 24),
                                for (final kind in ManagementKind.values) ...[
                                  ManagementLabel(
                                      'management_kind_${kind.name}'.tr()),
                                  const SizedBox(height: 12),
                                  Material(
                                    color: context.glass.overlay,
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(children: [
                                      for (final item in inventory.items
                                          .where((i) => i.key.kind == kind))
                                        ManagementItemRow(
                                            item: item,
                                            groupName: inventory
                                                .group(item.groupId)
                                                ?.name,
                                            selected: draft.members
                                                .contains(item.key),
                                            onTap: draft.saving
                                                ? null
                                                : () => select(item)),
                                    ]),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                              if (draft.step == GroupEditorStep.review) ...[
                                const SizedBox(height: 44),
                                ManagementLabel('management_members'.tr()),
                                const SizedBox(height: 12),
                                Material(
                                  color: context.glass.overlay,
                                  borderRadius: BorderRadius.circular(12),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(children: [
                                    for (final kind in ManagementKind.values)
                                      for (final key in draft.members
                                          .where((m) => m.kind == kind))
                                        if (inventory.item(key)
                                            case final item?)
                                          ManagementItemRow(
                                            item: item,
                                            showArrow: initial.groupId != null,
                                            onTap: initial.groupId == null ||
                                                    draft.saving
                                                ? null
                                                : () => context.push(item
                                                            .key.kind ==
                                                        ManagementKind.pet
                                                    ? '/my-pets/${item.key.id}/edit'
                                                    : '/devices/${item.key.kind.name}/${item.key.id}'),
                                          ),
                                  ]),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                        color: context.glass.overlay,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: TextButton(
                                        style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16)),
                                        onPressed: draft.saving
                                            ? null
                                            : () => ref
                                                .read(
                                                    groupEditorControllerProvider
                                                        .notifier)
                                                .step(GroupEditorStep.members),
                                        child: Row(children: [
                                          FigmaIcon.tinted(FigmaIcons.add,
                                              size: 24,
                                              color: context.glass.navSelected),
                                          const SizedBox(width: 4),
                                          Text('management_add_change'.tr(),
                                              style: managementStyle(context,
                                                  weight: FontWeight.w600,
                                                  color: context
                                                      .glass.navSelected)
                                                  .copyWith(height: 28 / 16))
                                        ]))),
                              ],
                              if (draft.errorKey != null)
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(draft.errorKey!.tr(),
                                        key: const Key('management_save_error'),
                                        style: managementStyle(context,
                                            size: 14,
                                            color: context.glass.navSelected))),
                            ]),
                        if (floatingSelection)
                          Positioned(
                              left: 0,
                              right: 0,
                              bottom: buttonBottom,
                              child: nextButton),
                      ])),
                      if (!floatingSelection) nextButton,
                      if (draft.groupId != null &&
                          draft.step == GroupEditorStep.review)
                        SizedBox(
                            height: 56,
                            child: TextButton(
                                key: const Key('management_delete_group'),
                                onPressed: draft.saving ? null : deleteGroup,
                                child: Text('management_delete_group'.tr(),
                                    style: managementStyle(context,
                                            size: 18,
                                            weight: FontWeight.w600,
                                            color: context.glass.navSelected)
                                        .copyWith(height: 28 / 18)))),
                      if (!floatingSelection)
                        SizedBox(
                            height: draft.groupId != null &&
                                    draft.step == GroupEditorStep.review
                                ? 10
                                : (100 - MediaQuery.paddingOf(context).bottom)
                                    .clamp(16, 100)),
                    ])))));
  }
}
