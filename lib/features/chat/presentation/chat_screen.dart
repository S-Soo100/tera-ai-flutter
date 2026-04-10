import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';
import 'chat_providers.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/quota_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  final String? petId;
  final String? speciesId;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.petId,
    this.speciesId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late String _conversationId;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.conversationId == null) {
      _conversationId = const Uuid().v4();
      final conv = Conversation(
        id: _conversationId,
        title: '새 대화',
        petId: widget.petId,
        speciesId: widget.speciesId,
        createdAt: DateTime.now(),
      );
      ref.read(chatRepositoryProvider).createConversation(conv);
    } else {
      _conversationId = widget.conversationId!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;

    _textController.clear();
    _scrollToBottom();

    final notifier =
        ref.read(chatMessagesProvider(_conversationId).notifier);
    await notifier.sendMessage(trimmed);

    // 첫 메시지이면 대화 제목 업데이트
    final messages =
        ref.read(chatMessagesProvider(_conversationId)).messages;
    if (messages.length <= 2) {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conv = chatRepo.getConversation(_conversationId);
      if (conv != null && conv.title == '새 대화') {
        final newTitle =
            trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
        conv.title = newTitle;
        await chatRepo.updateConversation(conv);
      }
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatMessagesProvider(_conversationId));
    final remaining = ref.watch(remainingMessagesProvider);
    final isExhausted = remaining <= 0;
    final conv =
        ref.watch(chatRepositoryProvider).getConversation(_conversationId);
    final colorScheme = Theme.of(context).colorScheme;

    // 에러 SnackBar
    ref.listen(chatMessagesProvider(_conversationId), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final errorMsg = next.error == 'quota_exceeded'
            ? '오늘 질문 횟수를 다 사용했어요. 내일 다시 이용해주세요.'
            : '답변을 가져오지 못했습니다. 다시 시도해주세요.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        ref.read(chatMessagesProvider(_conversationId).notifier).clearError();
      }
    });

    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          conv?.title ?? 'AI 채팅',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: '기록',
            onPressed: () => context.push('/chat'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 한도 표시
            const QuotaIndicator(),

            // 메시지 영역
            Expanded(
              child: chatState.messages.isEmpty
                  ? _WelcomeView(
                      onExampleTap: _sendMessage,
                      isLoading: chatState.isLoading,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: chatState.messages.length +
                          (chatState.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatState.messages.length) {
                          return const _LoadingBubble();
                        }
                        final msg = chatState.messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ChatBubble(
                            message: msg,
                            onReportBad: msg.role == 'assistant'
                                ? () async {
                                    await ref
                                        .read(chatMessagesProvider(
                                                _conversationId)
                                            .notifier)
                                        .reportBadAnswer(msg.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '피드백 감사합니다. 답변 품질 개선에 반영됩니다.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),

            // 입력바
            _InputBar(
              controller: _textController,
              focusNode: _focusNode,
              isLoading: chatState.isLoading,
              isExhausted: isExhausted,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// --- 환영 화면 ---

class _WelcomeView extends StatelessWidget {
  final void Function(String) onExampleTap;
  final bool isLoading;

  const _WelcomeView({
    required this.onExampleTap,
    required this.isLoading,
  });

  static const _examples = [
    '레오파드 게코 온도 세팅은?',
    '크레스티드 게코 먹이 추천',
    '탈피가 잘 안 돼요',
    '초보가 자주 하는 실수는?',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_rounded,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '사육이 궁금하다면\n무엇이든 물어보세요!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '레오파드 · 크레스티드 · 펫테일 게코 전문',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _examples
                  .map((q) => _ExampleChip(
                        label: q,
                        onTap: isLoading ? null : () => onExampleTap(q),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ExampleChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}

// --- 로딩 버블 ---

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4, right: 64),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '답변 생성 중...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 입력바 (토스 스타일) ---

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final bool isExhausted;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.isExhausted,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = isLoading || isExhausted;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExhausted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              child: Text(
                '오늘 질문 횟수를 다 사용했어요',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !isDisabled,
                      decoration: const InputDecoration(
                        hintText: '질문을 입력하세요...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: isDisabled ? null : onSend,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _SendButton(
                  isDisabled: isDisabled,
                  onTap: () => onSend(controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isDisabled;
  final VoidCallback onTap;

  const _SendButton({required this.isDisabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: isDisabled
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 22,
            color: isDisabled
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                : colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
