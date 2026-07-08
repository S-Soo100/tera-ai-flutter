import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../my_cage/presentation/nightly_report_view.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';

enum _MyPetsTab { list, report }

class MyPetsScreen extends ConsumerStatefulWidget {
  const MyPetsScreen({super.key});

  @override
  ConsumerState<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends ConsumerState<MyPetsScreen> {
  _MyPetsTab _selected = _MyPetsTab.list;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petListProvider);
    final intent = ref.watch(myPetsTabProvider);
    if (intent == 1 && _selected != _MyPetsTab.report) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selected = _MyPetsTab.report);
          ref.read(myPetsTabProvider.notifier).state = 0;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'my_pets_title'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CircleAddButton(
              onTap: () => context.push('/my-pets/add'),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TabChips(
              selected: _selected,
              onChanged: (t) => setState(() => _selected = t),
            ),
          ),
          const SizedBox(height: AppStyles.spacing16),
          Expanded(child: _tabContent(_selected, pets)),
        ],
      ),
    );
  }

  Widget _tabContent(_MyPetsTab selected, List<Pet> pets) {
    switch (selected) {
      case _MyPetsTab.list:
        return _PetListView(pets: pets);
      case _MyPetsTab.report:
        return const NightlyReportView();
    }
  }
}

// ── 상단 칩 탭 ────────────────────────────────────────────────────────────────

class _TabChips extends StatelessWidget {
  const _TabChips({required this.selected, required this.onChanged});

  final _MyPetsTab selected;
  final ValueChanged<_MyPetsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_MyPetsTab.list, 'my_pets_tab_list'.tr()),
      (_MyPetsTab.report, 'my_pets_tab_report'.tr()),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((entry) {
          final (tab, label) = entry;
          final isSelected = selected == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Chip(
              label: label,
              selected: isSelected,
              onTap: () => onChanged(tab),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF2E7D32);
    final bg = selected
        ? greenColor
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final fg = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CircleAddButton extends StatelessWidget {
  const _CircleAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.add, size: 20),
        ),
      ),
    );
  }
}

// ── 개체 목록 뷰 ──────────────────────────────────────────────────────────────

class _PetListView extends StatelessWidget {
  const _PetListView({required this.pets});
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        ...pets.map((pet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PetCard(pet: pet),
            )),
        _AddPetCard(),
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppStyles.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/my-pets/${pet.id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PetThumbnail(pet: pet),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pet.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SexBadge(sex: pet.sex),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle(pet),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (pet.adoptionDate != null)
                        Text(
                          'my_pets_adoption_date'.tr(
                            namedArgs: {
                              'date': _formatDate(pet.adoptionDate!),
                            },
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/my-pets/${pet.id}/edit'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: Text('my_pets_edit_info'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(Pet pet) {
    final parts = <String>[];
    if (pet.morph != null && pet.morph!.isNotEmpty) parts.add(pet.morph!);
    if (pet.weight != null) {
      parts.add('${pet.weight!.toStringAsFixed(0)}g');
    }
    if (parts.isEmpty) return pet.speciesName;
    return parts.join(' | ');
  }

  String _formatDate(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

class _PetThumbnail extends StatelessWidget {
  const _PetThumbnail({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = pet.photoPath != null && pet.photoPath!.isNotEmpty;
    final isNetwork = hasPhoto && pet.photoPath!.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        height: 80,
        child: hasPhoto
            ? (isNetwork
                ? CachedNetworkImage(
                    imageUrl: pet.photoPath!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _fallback(context),
                    errorWidget: (_, __, ___) => _fallback(context),
                  )
                : Image.file(
                    File(pet.photoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(context),
                  ))
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Image.asset('assets/images/logo.png', width: 36, height: 36),
      ),
    );
  }
}

class _SexBadge extends StatelessWidget {
  const _SexBadge({required this.sex});
  final String sex;

  @override
  Widget build(BuildContext context) {
    if (sex == 'unknown') return const SizedBox.shrink();
    final isMale = sex == 'male';
    final color = isMale ? const Color(0xFFE91E63) : const Color(0xFFE91E63);
    final bg = const Color(0xFFFCE4EC);
    final label = isMale ? 'pet_sex_male'.tr() : 'pet_sex_female'.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddPetCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/my-pets/add'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'my_pets_add_new_title'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'my_pets_add_new_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
