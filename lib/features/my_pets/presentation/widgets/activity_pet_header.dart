import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/activity_colors.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../domain/pet.dart';

/// Figma 765:4988: 112 high, 16 inset, 80 image, radius 12/4.
class ActivityPetHeader extends StatelessWidget {
  const ActivityPetHeader({super.key, required this.pet, this.onEdit});
  final Pet pet;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final theme = Theme.of(context);
    final photo = pet.photoPath;
    const placeholder =
        Image(image: FigmaImages.petPlaceholder, fit: BoxFit.contain);
    final Widget image = photo == null || photo.isEmpty
        ? placeholder
        : photo.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => placeholder)
            : Image.file(File(photo),
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    final details = [
      if (pet.morph?.isNotEmpty == true) pet.morph!,
      if (pet.weight != null)
        'activity_weight'
            .tr(namedArgs: {'value': NumberFormat('0.#').format(pet.weight)}),
    ].join(' | ');
    return Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: glass.overlay, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                  width: 80,
                  height: 80,
                  child: ColoredBox(color: glass.surfaceHeader, child: image))),
          const SizedBox(width: 16),
          Expanded(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(pet.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.32,
                                      color: glass.textSecondary))),
                          const SizedBox(width: 8),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: glass.surfaceHeader,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                  'activity_sex_${pet.sex == 'male' || pet.sex == 'female' ? pet.sex : 'unknown'}'
                                      .tr(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.28,
                                      color: pet.sex == 'female'
                                          ? ActivityColors.female
                                          : pet.sex == 'male'
                                              ? ActivityColors.male
                                              : glass.bodySecondary))),
                        ]),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.28,
                                  color: glass.textSecondary))
                        ],
                        if (pet.adoptionDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                              'activity_adopted'.tr(namedArgs: {
                                'date': DateFormat('yyyy. M. d')
                                    .format(pet.adoptionDate!)
                              }),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12, color: glass.bodySecondary))
                        ],
                      ]))),
          if (onEdit != null)
            SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'activity_edit_pet'.tr(),
                    onPressed: onEdit,
                    icon: FigmaIcon.tinted(FigmaIcons.more,
                        size: 24, color: glass.bodySecondary))),
        ]));
  }
}
