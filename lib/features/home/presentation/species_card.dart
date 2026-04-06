import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/species.dart';
import '../../../shared/widgets/legal_badge.dart';

class SpeciesCard extends ConsumerWidget {
  final Species species;

  const SpeciesCard({super.key, required this.species});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const LegalBadge(),
      title: Text(species.koreanName),
      subtitle: Text(
        species.scientificName,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      trailing: Text(species.category),
      onTap: () {
        context.push('/species/${species.id}');
      },
    );
  }
}
