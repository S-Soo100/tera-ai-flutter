import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../domain/knowledge_entry.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository();
});

class KnowledgeRepository {
  Box<KnowledgeEntry> get _box => Hive.box<KnowledgeEntry>('knowledge_entries');

  List<KnowledgeEntry> getAllEntries() {
    return _box.values.toList();
  }

  List<KnowledgeEntry> getEntriesBySpecies(String speciesId) {
    return _box.values.where((e) => e.speciesId == speciesId).toList();
  }

  List<KnowledgeEntry> findRelevant(
    String question,
    String speciesId, {
    int limit = 3,
  }) {
    final questionKeywords = extractKeywords(question);
    final speciesEntries = getEntriesBySpecies(speciesId);

    final scored = <({KnowledgeEntry entry, double score})>[];
    for (final entry in speciesEntries) {
      final entryKeywordSet = entry.keywords.toSet();
      final questionKeywordSet = questionKeywords.toSet();
      final overlap =
          entryKeywordSet.intersection(questionKeywordSet).length.toDouble();
      if (overlap == 0) continue;
      final score =
          overlap * entry.confidence * (1 + log(entry.useCount + 1));
      if (score > 0.5) {
        scored.add((entry: entry, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.entry).toList();
  }

  bool isCacheHit(String question, String speciesId) {
    final questionKeywords = extractKeywords(question);
    final speciesEntries = getEntriesBySpecies(speciesId);

    for (final entry in speciesEntries) {
      final entryKeywordSet = entry.keywords.toSet();
      final questionKeywordSet = questionKeywords.toSet();
      final overlap =
          entryKeywordSet.intersection(questionKeywordSet).length.toDouble();
      final score =
          overlap * entry.confidence * (1 + log(entry.useCount + 1));
      if (score > 2.0) return true;
    }
    return false;
  }

  Future<void> addEntry(KnowledgeEntry entry) async {
    await _box.put(entry.id, entry);
  }

  Future<void> incrementUseCount(String id) async {
    final entry = _box.get(id);
    if (entry == null) return;
    entry.useCount++;
    // confidence 소폭 상승 (최대 0.9 — 사람 검증 없이 1.0에 도달 못하게)
    if (entry.confidence < 0.9) {
      entry.confidence = (entry.confidence + 0.05).clamp(0.0, 0.9);
    }
    await _box.put(id, entry);
  }

  Future<void> reportBadAnswer(String id) async {
    final entry = _box.get(id);
    if (entry == null) return;
    entry.confidence -= 0.3;
    if (entry.confidence <= 0.1) {
      // 신뢰도가 너무 낮으면 삭제
      await _box.delete(id);
    } else {
      await _box.put(id, entry);
    }
  }

  static List<String> extractKeywords(String text) {
    // 불용어 제거
    const stopWords = {
      '이', '가', '은', '는', '을', '를', '의', '에', '와', '과', '도',
      '그', '저', '제', '어', '아', '좀', '더', '많이', '너무', '어떻게',
      '하는', '하면', '하고', '있나요', '있어요', '인가요', '인지', '될까요',
      '어떤', '어느', '무슨', '왜', '언제', '어디', '뭐',
    };

    final cleaned = text
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ')
        .toLowerCase();

    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !stopWords.contains(t))
        .toList();

    return tokens.toSet().toList();
  }
}
