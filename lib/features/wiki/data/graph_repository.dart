import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/graph_entity.dart';

final graphRepositoryProvider = Provider<GraphRepository>((ref) {
  return GraphRepository();
});

class GraphRepository {
  final Map<String, GraphEntity> _entitiesById = {};
  final List<GraphRelation> _relations = [];
  final Map<String, List<GraphRelation>> _byFrom = {};
  final Map<String, List<GraphRelation>> _byTo = {};
  final Map<RelationType, List<GraphRelation>> _byType = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString('assets/data/graph.json');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    _entitiesById.clear();
    _relations.clear();
    _byFrom.clear();
    _byTo.clear();
    _byType.clear();

    for (final raw in (json['entities'] as List).cast<Map<String, dynamic>>()) {
      final e = GraphEntity.fromJson(raw);
      _entitiesById[e.id] = e;
    }

    for (final raw in (json['relations'] as List).cast<Map<String, dynamic>>()) {
      final r = GraphRelation.fromJson(raw);
      _relations.add(r);
      (_byFrom[r.from] ??= []).add(r);
      (_byTo[r.to] ??= []).add(r);
      (_byType[r.type] ??= []).add(r);
    }

    _loaded = true;
  }

  GraphEntity? entity(String id) => _entitiesById[id];

  List<GraphRelation> outgoing(String entityId, [RelationType? type]) {
    final list = _byFrom[entityId] ?? const [];
    if (type == null) return List.unmodifiable(list);
    return list.where((r) => r.type == type).toList(growable: false);
  }

  List<GraphRelation> incoming(String entityId, [RelationType? type]) {
    final list = _byTo[entityId] ?? const [];
    if (type == null) return List.unmodifiable(list);
    return list.where((r) => r.type == type).toList(growable: false);
  }

  /// BFS up to [depth] hops (bidirectional). Returns unique entities reached,
  /// excluding the starting entity itself. [depth] clamped to [1, 3].
  Set<GraphEntity> neighbors(String entityId, {int depth = 2}) {
    final d = depth.clamp(1, 3);
    final visited = <String>{entityId};
    var frontier = <String>{entityId};
    for (var i = 0; i < d; i++) {
      final next = <String>{};
      for (final id in frontier) {
        for (final r in _byFrom[id] ?? const <GraphRelation>[]) {
          if (visited.add(r.to)) next.add(r.to);
        }
        for (final r in _byTo[id] ?? const <GraphRelation>[]) {
          if (visited.add(r.from)) next.add(r.from);
        }
      }
      if (next.isEmpty) break;
      frontier = next;
    }
    visited.remove(entityId);
    return visited
        .map((id) => _entitiesById[id])
        .whereType<GraphEntity>()
        .toSet();
  }

  int get entityCount => _entitiesById.length;
  int get relationCount => _relations.length;
}
