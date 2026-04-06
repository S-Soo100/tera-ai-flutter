import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/species_repository.dart';
import '../domain/species.dart';

final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  return SpeciesRepository();
});

final selectedCategoryProvider = StateProvider<String>((ref) => '전체');

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredSpeciesProvider = Provider<List<Species>>((ref) {
  final repo = ref.watch(speciesRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider);

  var results = query.isNotEmpty ? repo.search(query) : repo.getAll();
  if (category != '전체') {
    results = results.where((s) => s.category == category).toList();
  }
  return results;
});
