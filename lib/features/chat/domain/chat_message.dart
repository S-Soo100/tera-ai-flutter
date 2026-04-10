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

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.tokenCount,
    this.fromCache = false,
    this.knowledgeEntryId,
  });
}
