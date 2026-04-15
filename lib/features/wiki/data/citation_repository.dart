import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/citation.dart';

final citationRepositoryProvider = Provider<CitationRepository>((ref) {
  return CitationRepository();
});

class CitationRepository {
  final Map<String, Citation> _byId = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString('assets/data/citations.json');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = (json['citations'] as List).cast<Map<String, dynamic>>();
    _byId.clear();
    for (final raw in list) {
      final c = Citation.fromJson(raw);
      _byId[c.id] = c;
    }
    _loaded = true;
  }

  Citation? byId(String id) => _byId[id];

  Future<List<Citation>> hydrate(List<String> ids) async {
    await load();
    final out = <Citation>[];
    for (final id in ids) {
      final c = _byId[id];
      if (c != null) out.add(c);
    }
    return out;
  }

  int get count => _byId.length;
}
