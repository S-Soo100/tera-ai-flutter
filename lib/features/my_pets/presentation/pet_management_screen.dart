import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../core/theme/activity_colors.dart';
import '../../../shared/domain/num_format.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';
import 'widgets/pet_form_screen.dart';

final _petDeletingProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Profile removal is injected only after the owner has verified the history
/// and camera retention contract. No direct DELETE is hidden in this screen.
class PetManagementScreen extends ConsumerWidget {
  const PetManagementScreen(
      {super.key, this.onDelete, this.onAdd, this.onEdit});
  final Future<void> Function(Pet)? onDelete;
  final VoidCallback? onAdd;
  final ValueChanged<Pet>? onEdit;

  Future<void> _delete(BuildContext context, WidgetRef ref, Pet pet) async {
    if (ref.read(_petDeletingProvider) != null) return;
    final titleKey = switch (managementNameHasFinalConsonant(pet.name)) {
      true => 'pet_form_delete_title',
      false => 'pet_form_delete_title_open',
      null => 'pet_form_delete_title_unknown',
    };
    final message = '${titleKey.tr(namedArgs: {'name': pet.name})}\n'
        '${'pet_form_delete_body'.tr()}';
    final accepted =
        await managementConfirm(context, message, action: 'common_delete'.tr());
    if (accepted != true || !context.mounted) return;
    final handler = onDelete;
    if (handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('pet_form_delete_unavailable'.tr())));
      return;
    }
    ref.read(_petDeletingProvider.notifier).state = pet.id;
    try {
      await handler(pet);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('pet_form_delete_failed'.tr())));
      }
    } finally {
      if (context.mounted) ref.read(_petDeletingProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petListProvider);
    final deleting = ref.watch(_petDeletingProvider);
    final p = context.glass;
    void add() => onAdd != null ? onAdd!() : context.push('/my-pets/add');
    void edit(Pet pet) =>
        onEdit != null ? onEdit!(pet) : context.push('/my-pets/${pet.id}/edit');
    return Scaffold(
      backgroundColor: p.surfaceHeader,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            ManagementTopBar(
                title: 'pet_form_management'.tr(),
                close: true,
                onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: pets.isEmpty
                  ? const Center(
                      child: Image(
                          image: FigmaImages.emptyPet, width: 345, height: 227))
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      itemCount: pets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => _PetManagementCard(
                          pet: pets[index],
                          enabled: deleting == null,
                          onEdit: () => edit(pets[index]),
                          onDelete: () => _delete(context, ref, pets[index])),
                    ),
            ),
            ManagementButton(
                key: const Key('pet_management_add'),
                label: 'pet_form_add'.tr(),
                red: true,
                onPressed: deleting == null ? add : null),
            SizedBox(
                height: (100 - MediaQuery.paddingOf(context).bottom)
                    .clamp(16.0, 100.0)),
          ]),
        ),
      ),
    );
  }
}

class _PetManagementCard extends StatelessWidget {
  const _PetManagementCard({
    required this.pet,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });
  final Pet pet;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.glass;
    final sex = ['male', 'female'].contains(pet.sex) ? pet.sex : 'unknown';
    final detail = [
      if (pet.morph?.isNotEmpty ?? false) pet.morph!,
      if (pet.weight != null)
        'pet_form_weight_value'.tr(args: [formatCompact(pet.weight!)]),
    ].join(' | ');
    return Container(
      key: ValueKey('pet_management_card_${pet.id}'),
      constraints: const BoxConstraints(minHeight: 112),
      decoration: BoxDecoration(
          color: p.overlay, borderRadius: BorderRadius.circular(12)),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox.square(
                    dimension: 80,
                    child: PetFormPhoto(
                        path: pet.photoPath, size: 80, placeholderSize: 80))),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(pet.name,
                            style: managementStyle(context,
                                weight: FontWeight.w700)),
                        Container(
                          height: 24,
                          constraints: const BoxConstraints(minWidth: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                              color: p.surfaceHeader,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('pet_form_sex_$sex'.tr(),
                                    style: managementStyle(context,
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: sex == 'female'
                                            ? ActivityColors.female
                                            : sex == 'male'
                                                ? ActivityColors.male
                                                : p.bodySecondary)),
                              ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(detail.isEmpty ? pet.speciesName : detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: managementStyle(context, size: 14)),
                  ],
                ),
              ),
            ),
          ]),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SizedBox.square(
            dimension: 40,
            child: PopupMenuButton<String>(
              key: ValueKey('pet_management_menu_${pet.id}'),
              enabled: enabled,
              tooltip: 'pet_form_more'.tr(),
              position: PopupMenuPosition.under,
              // PopupMenuPosition.under subtracts half the icon padding.
              offset: const Offset(8, 8),
              constraints: const BoxConstraints.tightFor(width: 140),
              menuPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: p.surfaceHeader,
              surfaceTintColor: p.surfaceHeader,
              elevation: 6,
              shadowColor: p.textPrimary.withValues(alpha: .12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: FigmaIcon.tinted(FigmaIcons.more,
                  color: p.textSecondary, size: 24),
              onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                for (final action in ['edit', 'delete'])
                  PopupMenuItem<String>(
                    value: action,
                    height: 44,
                    padding: EdgeInsets.zero,
                    child: Container(
                      height: 44,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: action == 'edit'
                          ? BoxDecoration(
                              border:
                                  Border(bottom: BorderSide(color: p.border)))
                          : null,
                      child: Text('pet_form_$action'.tr(),
                          style: managementStyle(context,
                                  size: 18,
                                  color: action == 'delete'
                                      ? p.navSelected
                                      : p.textSecondary)
                              .copyWith(height: 28 / 18)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
