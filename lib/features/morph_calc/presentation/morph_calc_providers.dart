import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/morph_repository.dart';
import '../domain/morph_result.dart';

final morphRepositoryProvider = Provider<MorphRepository>((ref) {
  return MorphRepository();
});

final morphSpeciesListProvider = Provider<List<String>>((ref) {
  final repo = ref.watch(morphRepositoryProvider);
  return repo.getMorphSpecies();
});

final selectedMorphSpeciesProvider = StateProvider<String?>((ref) => null);

final selectedFatherProvider = StateProvider<String?>((ref) => null);

final selectedMotherProvider = StateProvider<String?>((ref) => null);

final availableMorphsProvider = Provider<List<String>>((ref) {
  final repo = ref.watch(morphRepositoryProvider);
  final speciesId = ref.watch(selectedMorphSpeciesProvider);
  if (speciesId == null) return [];
  return repo.getMorphsForSpecies(speciesId);
});

final morphResultProvider = Provider<MorphResult?>((ref) {
  final repo = ref.watch(morphRepositoryProvider);
  final speciesId = ref.watch(selectedMorphSpeciesProvider);
  final father = ref.watch(selectedFatherProvider);
  final mother = ref.watch(selectedMotherProvider);

  if (speciesId == null || father == null || mother == null) return null;

  return repo.getResult(
    speciesId: speciesId,
    father: father,
    mother: mother,
  );
});
