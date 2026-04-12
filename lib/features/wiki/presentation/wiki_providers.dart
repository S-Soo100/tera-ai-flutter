import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/care_info_repository.dart';
import '../data/citation_repository.dart';
import '../data/graph_repository.dart';
import '../domain/care_info_detail.dart';
import '../domain/citation.dart';
import '../domain/graph_entity.dart';
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

/// 종별 citation_ids → Citation 객체 리스트.
final speciesCitationsProvider =
    FutureProvider.family<List<Citation>, String>((ref, speciesId) async {
  final info = await ref.watch(careInfoProvider(speciesId).future);
  if (info.citationIds.isEmpty) return const [];
  final repo = ref.watch(citationRepositoryProvider);
  return repo.hydrate(info.citationIds);
});

/// 종별 outgoing 관계 — RelationType별 그룹핑 + 대상 Entity 포함.
class SpeciesRelationGroup {
  final RelationType type;
  final List<({GraphRelation relation, GraphEntity target})> items;
  const SpeciesRelationGroup({required this.type, required this.items});
}

final speciesRelationsProvider =
    FutureProvider.family<List<SpeciesRelationGroup>, String>(
        (ref, speciesId) async {
  final info = await ref.watch(careInfoProvider(speciesId).future);
  final entityId = info.graphEntityId;
  if (entityId == null) return const [];
  final repo = ref.watch(graphRepositoryProvider);
  await repo.load();
  final relations = repo.outgoing(entityId);
  if (relations.isEmpty) return const [];

  final grouped = <RelationType, List<({GraphRelation relation, GraphEntity target})>>{};
  for (final r in relations) {
    final target = repo.entity(r.to);
    if (target == null) continue;
    (grouped[r.type] ??= []).add((relation: r, target: target));
  }
  return grouped.entries
      .map((e) => SpeciesRelationGroup(type: e.key, items: e.value))
      .toList(growable: false);
});
