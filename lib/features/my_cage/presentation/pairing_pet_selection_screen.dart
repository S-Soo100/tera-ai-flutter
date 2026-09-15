import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../my_pets/domain/pet.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../domain/redesign_management.dart';
import 'device_management_controller.dart';
import 'widgets/management_widgets.dart';

/// Kept separate so the selection UI has a stable, easily overridden read
/// model while group persistence remains exclusively in [GroupEditorController].
final pairingPetsProvider =
    Provider.autoDispose<List<Pet>>((ref) => ref.watch(petListProvider));

/// Post-pairing choice of the single pet assigned to an enclosure group.
class PairingPetSelectionScreen extends ConsumerWidget {
  const PairingPetSelectionScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(redesignGroupRepositoryProvider);
    final inventory = ref.watch(managementInventoryProvider);
    final pets = ref.watch(pairingPetsProvider);
    return inventory.when(
      loading: () => const Scaffold(body: SafeArea(child: SizedBox())),
      error: (_, __) => Scaffold(
          body: Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(managementInventoryProvider),
                  child: Text('management_load_retry'.tr())))),
      data: (value) {
        final group = value.group(groupId);
        if (repo == null || group == null) {
          return Scaffold(
              body: Center(child: Text('management_item_missing'.tr())));
        }
        final draft = GroupEditDraft.existing(group, value);
        return ProviderScope(
            key: ValueKey((repo, groupId)),
            overrides: [
              groupEditorControllerProvider
                  .overrideWith((ref) => GroupEditorController(repo, draft)),
            ],
            child: _PairingPetSelectionBody(
                group: group, inventory: value, initial: draft, pets: pets));
      },
    );
  }
}

class _PairingPetSelectionBody extends ConsumerWidget {
  const _PairingPetSelectionBody(
      {required this.group,
      required this.inventory,
      required this.initial,
      required this.pets});
  final ManagementGroup group;
  final ManagementInventory inventory;
  final GroupEditDraft initial;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(groupEditorControllerProvider);
    final petsById = {for (final pet in pets) pet.id: pet};
    final registered = inventory.items
        .where((item) => item.key.kind == ManagementKind.pet)
        .toList();

    Future<void> select(ManagementItem item) async {
      if (draft.saving || draft.members.contains(item.key)) return;
      if (draft.requiresMoveConfirmation(item)) {
        final confirmed = await managementConfirm(
            context,
            'management_move_confirm'.tr(namedArgs: {
              'item': item.name,
              'group': inventory.group(item.groupId)?.name ??
                  'management_group'.tr(),
              'target': group.name,
            }),
            action: 'management_move'.tr());
        if (!confirmed || !context.mounted) return;
      }
      ref.read(groupEditorControllerProvider.notifier).select(item);
    }

    Future<void> save() async {
      final saved = await ref
          .read(groupEditorControllerProvider.notifier)
          .save(inventory);
      if (!saved || !context.mounted) return;
      ref.read(managementMutationCompletedProvider)();
      context.go('/home');
    }

    Future<void> registerPet() async {
      await context.push('/pet-add', extra: group.id);
      if (context.mounted) ref.invalidate(managementInventoryProvider);
    }

    final hasSelectedPet =
        draft.members.any((member) => member.kind == ManagementKind.pet);
    final safeTop = MediaQuery.paddingOf(context).top;
    return PopScope(
        canPop: !draft.saving,
        child: Scaffold(body:
            SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final titleTop = constraints.maxHeight < 650
              ? 24.0
              : (174 - safeTop)
                  .clamp(24.0, constraints.maxHeight * .24)
                  .toDouble();
          return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(children: [
                SizedBox(height: titleTop),
                Text(
                    (registered.length == 1
                            ? 'pairing_pet_single_title'
                            : 'pairing_pet_title')
                        .tr(),
                    textAlign: TextAlign.center,
                    style: managementStyle(context,
                        size: 18,
                        weight: FontWeight.w600,
                        color: context.glass.textSecondary)),
                const SizedBox(height: 8),
                Text('pairing_pet_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: managementStyle(context,
                        size: 16, color: context.glass.bodySecondary)),
                const SizedBox(height: 24),
                Expanded(
                    child: registered.isEmpty
                        ? _EmptyPets(onRegister: registerPet)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: registered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = registered[index];
                              final pet = petsById[item.key.id] ??
                                  Pet(
                                      id: item.key.id,
                                      name: item.name,
                                      speciesId: '',
                                      speciesName: '',
                                      morph: item.subtitle,
                                      createdAt: DateTime(0),
                                      updatedAt: DateTime(0));
                              return _PetChoiceCard(
                                  item: item,
                                  pet: pet,
                                  selected: draft.members.contains(item.key),
                                  enabled: !draft.saving,
                                  onTap: () => select(item));
                            })),
                if (draft.errorKey != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(draft.errorKey!.tr(),
                          style: managementStyle(context,
                              size: 14, color: context.glass.navSelected))),
                if (registered.isNotEmpty)
                  SizedBox(
                      key: const Key('pairing_pet_save'),
                      child: ManagementButton(
                          label: 'pairing_pet_primary_action'.tr(),
                          onPressed: draft.saving ||
                                  registered.isEmpty ||
                                  !hasSelectedPet
                              ? null
                              : save)),
                const SizedBox(height: 6),
                SizedBox(
                    height: 48,
                    child: TextButton(
                        key: const Key('pairing_pet_later'),
                        onPressed:
                            draft.saving ? null : () => context.go('/home'),
                        child: Text('pairing_pet_later'.tr(),
                            style: managementStyle(context,
                                size: 18,
                                weight: FontWeight.w600,
                                color: context.glass.textSecondary)))),
              ]));
        }))));
  }
}

class _PetChoiceCard extends StatelessWidget {
  const _PetChoiceCard(
      {required this.item,
      required this.pet,
      required this.selected,
      required this.enabled,
      required this.onTap});
  final ManagementItem item;
  final Pet pet;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
          key: Key('pairing_pet_${pet.id}'),
          height: 112,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: context.glass.overlayFaint,
              borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _PetPhoto(pet: pet),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        child: Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: managementStyle(context,
                                weight: FontWeight.w700,
                                color: context.glass.textSecondary))),
                    const SizedBox(width: 8),
                    _SexTag(sex: pet.sex),
                  ]),
                  const SizedBox(height: 6),
                  Text(_details(pet),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: managementStyle(context,
                          size: 14, color: context.glass.textSecondary)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              FigmaIcon.tinted(
                  selected
                      ? 'redesign_v2/check_box_300'
                      : 'redesign_v2/check_box_outline_blank_400',
                  size: 24,
                  color: selected
                      ? context.glass.navSelected
                      : context.glass.deviceOff),
              const Spacer(),
            ]),
          ])));

  String _details(Pet pet) => [
        if (pet.morph?.isNotEmpty ?? false) pet.morph!,
        if (pet.weight != null) '${NumberFormat('0.#').format(pet.weight)}g',
      ].join(' | ');
}

class _SexTag extends StatelessWidget {
  const _SexTag({required this.sex});
  final String sex;

  @override
  Widget build(BuildContext context) {
    final normalized = switch (sex) {
      'female' => 'female',
      'male' => 'male',
      _ => 'unknown',
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
            color: context.glass.surfaceHeader,
            borderRadius: BorderRadius.circular(4)),
        child: Text('pet_form_sex_$normalized'.tr(),
            style: managementStyle(context,
                size: 14,
                weight: FontWeight.w700,
                color: normalized == 'female'
                    ? context.glass.signalAlert
                    : context.glass.textSecondary)));
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets({required this.onRegister});
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image(image: FigmaImages.emptyPet, width: 160, height: 106),
            const SizedBox(height: 20),
            Text('pairing_pet_empty_title'.tr(),
                style: managementStyle(context,
                    size: 18,
                    weight: FontWeight.w700,
                    color: context.glass.textPrimary)),
            const SizedBox(height: 8),
            Text('pairing_pet_empty_body'.tr(),
                textAlign: TextAlign.center,
                style: managementStyle(context,
                    color: context.glass.textTertiary)),
            const SizedBox(height: 20),
            OutlinedButton(
                onPressed: onRegister,
                child: Text('pairing_pet_register_action'.tr())),
          ])));
}

class _PetPhoto extends StatelessWidget {
  const _PetPhoto({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final path = pet.photoPath;
    final placeholder = ColoredBox(
        color: context.glass.surfaceHeader,
        child: Image(image: FigmaImages.petPlaceholder, fit: BoxFit.contain));
    Widget image = placeholder;
    if (path != null && path.isNotEmpty) {
      image = path.startsWith('http')
          ? Image.network(path,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)
          : Image.file(File(path),
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 80, height: 80, child: image));
  }
}
