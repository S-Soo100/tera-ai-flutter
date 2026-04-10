import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/chat_repository.dart';
import '../data/knowledge_repository.dart';
import '../data/groq_api_repository.dart';
import '../data/context_builder.dart';
import '../data/knowledge_extractor.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';

// 대화 목록 Provider
final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, List<Conversation>>((ref) {
  return ConversationListNotifier(ref);
});

class ConversationListNotifier extends StateNotifier<List<Conversation>> {
  final Ref ref;

  ConversationListNotifier(this.ref) : super([]) {
    refresh();
  }

  void refresh() {
    state = ref.read(chatRepositoryProvider).getAllConversations();
  }

  Future<void> deleteConversation(String id) async {
    await ref.read(chatRepositoryProvider).deleteConversation(id);
    refresh();
  }
}

// 채팅 상태
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// 채팅 메시지 Provider (conversation별)
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier,
    ChatState, String>((ref, conversationId) {
  return ChatMessagesNotifier(ref, conversationId);
});

class ChatMessagesNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  final String conversationId;

  ChatMessagesNotifier(this.ref, this.conversationId)
      : super(const ChatState()) {
    _loadMessages();
  }

  void _loadMessages() {
    final messages =
        ref.read(chatRepositoryProvider).getMessages(conversationId);
    state = state.copyWith(messages: messages);
  }

  Future<void> sendMessage(String question) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    // 한도 체크
    if (!chatRepo.canSendMessage()) {
      state = state.copyWith(error: 'quota_exceeded');
      return;
    }

    const uuid = Uuid();

    // 사용자 메시지 저장
    final userMsg = ChatMessage(
      id: uuid.v4(),
      conversationId: conversationId,
      role: 'user',
      content: question,
      createdAt: DateTime.now(),
    );
    await chatRepo.addMessage(userMsg);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    // 대화의 speciesId 가져오기
    final conv = chatRepo.getConversation(conversationId);
    final speciesId = conv?.speciesId;

    // 캐시 히트 체크
    final knowledgeRepo = ref.read(knowledgeRepositoryProvider);
    final detectedSpecies =
        ref.read(contextBuilderProvider).detectSpecies(question, speciesId);

    if (detectedSpecies != null &&
        knowledgeRepo.isCacheHit(question, detectedSpecies)) {
      final cached =
          knowledgeRepo.findRelevant(question, detectedSpecies, limit: 1);
      if (cached.isNotEmpty) {
        await knowledgeRepo.incrementUseCount(cached.first.id);
        final cachedMsg = ChatMessage(
          id: uuid.v4(),
          conversationId: conversationId,
          role: 'assistant',
          content: cached.first.answer,
          createdAt: DateTime.now(),
          fromCache: true,
          knowledgeEntryId: cached.first.id,
        );
        await chatRepo.addMessage(cachedMsg);
        // 캐시 히트는 한도 미차감
        state = state.copyWith(
          messages: [...state.messages, cachedMsg],
          isLoading: false,
        );
        ref.read(conversationListProvider.notifier).refresh();
        return;
      }
    }

    // API 호출
    try {
      final contextBuilder = ref.read(contextBuilderProvider);
      final result = await contextBuilder.buildContext(
        question: question,
        conversationId: conversationId,
        speciesId: speciesId,
        petId: conv?.petId,
      );

      final groqRepo = ref.read(groqApiRepositoryProvider);
      final response = await groqRepo.sendChat(messages: result.messages);

      if (!response.success) {
        state = state.copyWith(isLoading: false, error: response.error);
        return;
      }

      // 앱 레이어에서 출처 직접 첨부
      var finalContent = response.content;
      if (result.hasCareData && result.sources.isNotEmpty) {
        finalContent += '\n\n출처:\n${result.sources.map((s) => '- $s').join('\n')}';
      }
      if (!result.hasCareData) {
        finalContent += '\n\n일반 지식 기반 답변입니다. 전문가 확인을 권장합니다.';
      }

      // AI 응답 저장
      final assistantMsg = ChatMessage(
        id: uuid.v4(),
        conversationId: conversationId,
        role: 'assistant',
        content: finalContent,
        createdAt: DateTime.now(),
        tokenCount: response.completionTokens,
      );
      await chatRepo.addMessage(assistantMsg);
      await chatRepo.incrementQuota();
      ref.invalidate(remainingMessagesProvider);

      // 지식 추출 (speciesId 감지된 경우에만)
      if (detectedSpecies != null) {
        final extractor = KnowledgeExtractor();
        final entry = extractor.extract(
          question: question,
          answer: response.content,
          speciesId: detectedSpecies,
          conversationId: conversationId,
        );
        if (entry != null) {
          await knowledgeRepo.addEntry(entry);
        }
      }

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
      ref.read(conversationListProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reportBadAnswer(String messageId) async {
    final msg = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (msg == null || msg.knowledgeEntryId == null) return;
    final knowledgeRepo = ref.read(knowledgeRepositoryProvider);
    await knowledgeRepo.reportBadAnswer(msg.knowledgeEntryId!);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// 남은 메시지 수
final remainingMessagesProvider = Provider<int>((ref) {
  return ref.watch(chatRepositoryProvider).remainingMessages();
});
