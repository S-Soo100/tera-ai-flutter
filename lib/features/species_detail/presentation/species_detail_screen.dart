import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'species_detail_providers.dart';
import '../../home/presentation/home_providers.dart';
import 'care_info_card.dart';
import 'dday_banner.dart';

class SpeciesDetailScreen extends ConsumerWidget {
  final String speciesId;

  const SpeciesDetailScreen({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = ref.watch(speciesDetailProvider(speciesId));

    if (species == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/error');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final careInfo = ref.watch(careInfoProvider(speciesId));

    return Scaffold(
      appBar: AppBar(
        title: Text(species.koreanName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DdayBanner(),
          const SizedBox(height: 16),
          Text(
            species.scientificName,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
          Text(
            species.commonName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: species.tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'care_info_title'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (careInfo != null)
            CareInfoCard(careInfo: careInfo)
          else
            Text('care_info_preparing'.tr()),
          const SizedBox(height: 16),
          if (species.hasMorphData)
            ElevatedButton.icon(
              icon: const Icon(Icons.science),
              label: Text('morph_button'.tr()),
              onPressed: () => context.go('/morph-calc'),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.assignment),
            label: Text('guide_button'.tr()),
            onPressed: () => context.go('/guide'),
          ),
        ],
      ),
    );
  }
}
