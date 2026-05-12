import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/storage/safe_hive.dart';
import '../domain/chat_message.dart';
import '../domain/chat_quota.dart';
import '../domain/conversation.dart';
import '../domain/knowledge_entry.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatRepository {
  static const _conversationsBox = 'conversations';
  static const _messagesBox = 'chat_messages';
  static const _quotaBox = 'chat_quota';

  static const int dailyLimit = kDebugMode ? 999 : 20;

  Box<Conversation> get _convBox => Hive.box<Conversation>(_conversationsBox);
  Box<ChatMessage> get _msgBox => Hive.box<ChatMessage>(_messagesBox);
  Box<ChatQuota> get _qBox => Hive.box<ChatQuota>(_quotaBox);

  static Future<void> init() async {
    Hive.registerAdapter(ConversationAdapter());
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(KnowledgeEntryAdapter());
    Hive.registerAdapter(ChatQuotaAdapter());
    await openBoxSafely<Conversation>(_conversationsBox);
    await openBoxSafely<ChatMessage>(_messagesBox);
    await openBoxSafely<KnowledgeEntry>('knowledge_entries');
    await openBoxSafely<ChatQuota>(_quotaBox);
  }

  // Conversation CRUD

  List<Conversation> getAllConversations() {
    // 빈 세션(메시지 0개) 자동 정리 — 기존에 쌓인 빈 세션도 제거
    final emptyIds = _convBox.values
        .where((c) => !c.isArchived && c.messageCount == 0)
        .map((c) => c.id)
        .toList();
    for (final id in emptyIds) {
      _convBox.delete(id);
    }

    return _convBox.values
        .where((c) => !c.isArchived)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Conversation? getConversation(String id) {
    try {
      return _convBox.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> createConversation(Conversation conversation) async {
    await _convBox.put(conversation.id, conversation);
  }

  Future<void> updateConversation(Conversation conversation) async {
    conversation.updatedAt = DateTime.now();
    await _convBox.put(conversation.id, conversation);
  }

  Future<void> archiveConversation(String id) async {
    final conv = getConversation(id);
    if (conv == null) return;
    conv.isArchived = true;
    await _convBox.put(id, conv);
  }

  Future<void> deleteConversation(String id) async {
    await _convBox.delete(id);
    // cascade delete messages
    final toDelete = _msgBox.values
        .where((m) => m.conversationId == id)
        .map((m) => m.id)
        .toList();
    for (final msgId in toDelete) {
      await _msgBox.delete(msgId);
    }
  }

  // Message CRUD

  List<ChatMessage> getMessages(String conversationId) {
    return _msgBox.values
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<ChatMessage> getRecentMessages(String conversationId, {int limit = 10}) {
    final all = getMessages(conversationId);
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }

  Future<void> addMessage(ChatMessage message) async {
    await _msgBox.put(message.id, message);
    final conv = getConversation(message.conversationId);
    if (conv != null) {
      conv.messageCount++;
      conv.updatedAt = DateTime.now();
      await _convBox.put(conv.id, conv);
    }
  }

  // Quota

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  ChatQuota _getOrCreateQuota(String dateKey) {
    final existing = _qBox.get(dateKey);
    if (existing != null) return existing;
    return ChatQuota(date: dateKey);
  }

  ChatQuota getQuotaForToday() {
    return _getOrCreateQuota(_todayKey());
  }

  Future<void> incrementQuota() async {
    final key = _todayKey();
    final quota = _getOrCreateQuota(key);
    quota.messageCount++;
    await _qBox.put(key, quota);
  }

  bool canSendMessage() {
    return getQuotaForToday().messageCount < dailyLimit;
  }

  int remainingMessages() {
    return dailyLimit - getQuotaForToday().messageCount;
  }
}
