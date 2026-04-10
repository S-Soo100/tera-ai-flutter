import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/conversation.dart';
import 'chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _speciesInitial(Conversation conv) {
    if (conv.speciesId == null) return 'AI';
    switch (conv.speciesId) {
      case 'leopard-gecko':
        return 'LG';
      case 'crested-gecko':
        return 'CG';
      case 'fat-tailed-gecko':
        return 'FT';
      default:
        return conv.speciesId!.substring(0, 2).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('대화 기록'),
      ),
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 대화 기록이 없어요',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return Dismissible(
                  key: Key(conv.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Theme.of(context).colorScheme.error,
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('대화 삭제'),
                            content: const Text('이 대화를 삭제할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => ctx.pop(false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => ctx.pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(ctx).colorScheme.error,
                                ),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) {
                    ref
                        .read(conversationListProvider.notifier)
                        .deleteConversation(conv.id);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        _speciesInitial(conv),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    title: Text(conv.title),
                    subtitle: Text(
                      '메시지 ${conv.messageCount}개 · ${_relativeTime(conv.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    trailing: conv.speciesId != null
                        ? Chip(
                            label: Text(
                              conv.speciesId!,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                          )
                        : null,
                    onTap: () => context.push('/chat/${conv.id}'),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chat_list_fab',
        onPressed: () => context.push('/chat/new'),
        icon: const Icon(Icons.add),
        label: const Text('새 대화'),
      ),
    );
  }
}
