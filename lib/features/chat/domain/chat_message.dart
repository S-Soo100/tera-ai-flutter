import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 3)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final String role; // "user" | "assistant"

  @HiveField(3)
  final String content;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final int? tokenCount;

  @HiveField(6)
  final bool fromCache;

  @HiveField(7)
  final String? knowledgeEntryId;

  @HiveField(8)
  final List<String> citationIds;

  @HiveField(9)
  final String? sourceType; // "care_data" | "general_knowledge" | "web_search"

  @HiveField(10)
  final List<String> webSources; // 웹 검색 출처 ["title|url", ...]

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.tokenCount,
    this.fromCache = false,
    this.knowledgeEntryId,
    this.citationIds = const [],
    this.sourceType,
    this.webSources = const [],
  });
}
