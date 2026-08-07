import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/care_info_repository.dart';
import '../data/citation_repository.dart';
import '../domain/care_info_detail.dart';
import '../domain/citation.dart';
import '../domain/morph_genetics.dart';

final selectedWikiSpeciesProvider =
    StateProvider<String>((ref) => 'crested-gecko');

final careInfoProvider =
    FutureProvider.family<CareInfoDetail, String>((ref, speciesId) async {
  final repo = ref.watch(careInfoRepositoryProvider);
  return repo.getCareInfo(speciesId);
});

final morphDataProvider =
    FutureProvider.family<MorphGeneticsData, String>((ref, speciesId) async {
  final repo = ref.watch(careInfoRepositoryProvider);
  return repo.getMorphData(speciesId);
});

/// 종별 citation_ids → Citation 객체 리스트.
final speciesCitationsProvider =
    FutureProvider.family<List<Citation>, String>((ref, speciesId) async {
  final info = await ref.watch(careInfoProvider(speciesId).future);
  if (info.citationIds.isEmpty) return const [];
  final repo = ref.watch(citationRepositoryProvider);
  return repo.hydrate(info.citationIds);
});
