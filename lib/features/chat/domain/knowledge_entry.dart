import 'package:hive/hive.dart';

part 'knowledge_entry.g.dart';

@HiveType(typeId: 4)
class KnowledgeEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String question;

  @HiveField(2)
  final String answer;

  @HiveField(3)
  final String speciesId;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final List<String> keywords;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  int useCount;

  @HiveField(8)
  double confidence;

  @HiveField(9)
  final String sourceConversationId;

  KnowledgeEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.speciesId,
    required this.category,
    required this.keywords,
    required this.createdAt,
    this.useCount = 0,
    this.confidence = 0.5,
    required this.sourceConversationId,
  });
}
