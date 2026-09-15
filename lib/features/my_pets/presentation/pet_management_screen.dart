import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_palette.dart';
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
    final accepted = await managementConfirm(context, message,
        action: 'common_delete'.tr());
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
      appBar: petFormAppBar(context, 'pet_form_management'.tr(),
          () => Navigator.of(context).pop()),
      body: pets.isEmpty
          ? Center(
              child:
                  Image(image: FigmaImages.emptyPet, width: 345, height: 227))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              itemCount: pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final pet = pets[index];
                final sex =
                    ['male', 'female'].contains(pet.sex) ? pet.sex : 'unknown';
                final detail = [
                  if (pet.morph?.isNotEmpty ?? false) pet.morph!,
                  if (pet.weight != null)
                    'pet_form_weight_value'.tr(args: [pet.weight.toString()])
                ].join(' | ');
                return Container(
                    constraints: const BoxConstraints(minHeight: 112),
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    decoration: BoxDecoration(
                        color: p.surfaceTint,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      SizedBox(
                          width: 80,
                          height: 80,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  PetFormPhoto(path: pet.photoPath, size: 80))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(pet.name,
                                      style: petFormText(context).copyWith(
                                          fontWeight: FontWeight.w600)),
                                  Text('pet_form_sex_$sex'.tr(),
                                      style: petFormText(context).copyWith(
                                          fontSize: 14,
                                          color: p.textSecondary)),
                                ]),
                            const SizedBox(height: 8),
                            Text(detail.isEmpty ? pet.speciesName : detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: petFormText(context).copyWith(
                                    fontSize: 14, color: p.textSecondary)),
                          ])),
                      PopupMenuButton<String>(
                          enabled: deleting == null,
                          tooltip: 'pet_form_more'.tr(),
                          icon: FigmaIcon.tinted(FigmaIcons.more,
                              color: p.textSecondary, size: 24),
                          onSelected: (action) {
                            if (action == 'edit') {
                              edit(pet);
                            } else {
                              _delete(context, ref, pet);
                            }
                          },
                          itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text('pet_form_edit'.tr())),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text('pet_form_delete'.tr()))
                              ]),
                    ]));
              }),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: petFormButton(context, 'pet_form_add'.tr(),
                  deleting == null ? add : null))),
    );
  }
}
