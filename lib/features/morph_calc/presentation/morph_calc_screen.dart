import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'morph_calc_providers.dart';

class MorphCalcScreen extends ConsumerWidget {
  const MorphCalcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final morphSpecies = ref.watch(morphSpeciesListProvider);
    final selectedSpecies = ref.watch(selectedMorphSpeciesProvider);
    final availableMorphs = ref.watch(availableMorphsProvider);
    final selectedFather = ref.watch(selectedFatherProvider);
    final selectedMother = ref.watch(selectedMotherProvider);
    final morphResult = ref.watch(morphResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('morph_calc_title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'morph_select_species'.tr(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: selectedSpecies,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'morph_select_species'.tr(),
            ),
            items: morphSpecies.map((id) {
              return DropdownMenuItem(
                value: id,
                child: Text(id),
              );
            }).toList(),
            onChanged: (value) {
              ref.read(selectedMorphSpeciesProvider.notifier).state = value;
              ref.read(selectedFatherProvider.notifier).state = null;
              ref.read(selectedMotherProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: selectedFather,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'morph_father'.tr(),
            ),
            items: availableMorphs.map((morph) {
              return DropdownMenuItem(
                value: morph,
                child: Text(morph),
              );
            }).toList(),
            onChanged: selectedSpecies == null
                ? null
                : (value) {
                    ref.read(selectedFatherProvider.notifier).state = value;
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: selectedMother,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'morph_mother'.tr(),
            ),
            items: availableMorphs.map((morph) {
              return DropdownMenuItem(
                value: morph,
                child: Text(morph),
              );
            }).toList(),
            onChanged: selectedSpecies == null
                ? null
                : (value) {
                    ref.read(selectedMotherProvider.notifier).state = value;
                  },
          ),
          const SizedBox(height: 24),
          Text(
            'morph_result_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (morphResult == null)
            Text('morph_no_data'.tr())
          else
            ...morphResult.outcomes.map((outcome) {
              final pct = (outcome.probability * 100).toStringAsFixed(1);
              return Card(
                child: ListTile(
                  title: Text(outcome.name),
                  trailing: Text(
                    '$pct%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
