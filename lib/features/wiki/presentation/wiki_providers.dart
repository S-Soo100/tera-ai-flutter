import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/care_info_repository.dart';
import '../domain/care_info_detail.dart';
import '../domain/morph_genetics.dart';

final selectedWikiSpeciesProvider =
    StateProvider<String>((ref) => 'leopard-gecko');

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
