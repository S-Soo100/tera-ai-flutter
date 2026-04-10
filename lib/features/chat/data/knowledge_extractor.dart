import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/knowledge_entry.dart';
import 'context_builder.dart';
import 'knowledge_repository.dart';

final knowledgeExtractorProvider = Provider<KnowledgeExtractor>((ref) {
  return KnowledgeExtractor();
});

const _uuid = Uuid();

class KnowledgeExtractor {
  bool isExtractable(String question, String answer) {
    if (answer.length < 100) return false;
    if (_isGreeting(question)) return false;
    return _containsCareKeywords(question);
  }

  KnowledgeEntry? extract({
    required String question,
    required String answer,
    required String speciesId,
    required String conversationId,
  }) {
    if (!isExtractable(question, answer)) return null;
    final category = _detectCategory(question);
    final keywords =
        KnowledgeRepository.extractKeywords('$question $answer');
    return KnowledgeEntry(
      id: _uuid.v4(),
      question: question.trim(),
      answer: answer.length > 500 ? answer.substring(0, 500) : answer,
      speciesId: speciesId,
      category: category,
      keywords: keywords,
      createdAt: DateTime.now(),
      useCount: 0,
      confidence: 0.5,
      sourceConversationId: conversationId,
    );
  }

  bool _isGreeting(String q) {
    const greetings = ['안녕', '하이', 'hi', 'hello', '감사', '고마워'];
    final lower = q.toLowerCase().trim();
    return greetings
        .any((g) => lower == g || lower.startsWith('$g '));
  }

  bool _containsCareKeywords(String text) {
    for (final keywords in ContextBuilder.categoryKeywords.values) {
      for (final keyword in keywords) {
        if (text.contains(keyword)) return true;
      }
    }
    return false;
  }

  String _detectCategory(String question) {
    int bestCount = 0;
    String bestCategory = 'general';
    for (final entry in ContextBuilder.categoryKeywords.entries) {
      final count =
          entry.value.where((k) => question.contains(k)).length;
      if (count > bestCount) {
        bestCount = count;
        bestCategory = entry.key;
      }
    }
    return bestCategory;
  }
}
