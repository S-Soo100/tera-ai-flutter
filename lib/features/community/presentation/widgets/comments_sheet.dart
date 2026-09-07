import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/community_post.dart';
import '../community_providers.dart';
import 'post_card.dart' show showReportReasonsSheet;

/// 댓글 시트 — 피드 위에 떠서 맥락 유지 (시안 ④).
/// 닫히면 **그 게시물 하나만** 카운트를 동기화한다 — 전체 refresh는
/// 페이지네이션을 폐기하고 스크롤을 점프시킨다.
Future<void> showCommentsSheet(
    BuildContext context, WidgetRef ref, CommunityPost post) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CommentsSheet(postId: post.id),
  );
  // 시트가 떠 있는 동안 화면이 pop됐으면 ref도 죽어 있다.
  if (!context.mounted) return;
  await ref.read(communityFeedProvider.notifier).refreshPost(post.id);
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context); // async gap 전에 캡처
    setState(() => _sending = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .addComment(widget.postId, body);
      // 전송 중 시트가 닫혔으면 ref는 이미 dispose — 만지면 StateError.
      if (!mounted) return;
      _input.clear();
      ref.invalidate(commentsProvider(widget.postId));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text('community_comment_send_failed'.tr())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reportComment(String commentId, String reason) async {
    // async gap 전에 캡처.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityRepositoryProvider).report(
          targetKind: 'comment', targetId: commentId, reason: reason);
      messenger.showSnackBar(
          SnackBar(content: Text('community_report_done'.tr())));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text('community_report_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final comments = ref.watch(commentsProvider(widget.postId));
    final myId = ref.watch(currentUserProvider.select((u) => u?.id));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, scroll) => Column(children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: glass.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'community_comments_title'
                .tr(namedArgs: {'n': '${comments.valueOrNull?.length ?? ''}'}),
            style: glass.tileTitle,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: comments.when(
              // 투명 SizedBox를 Shimmer로 감싸면 칠할 픽셀이 없어 아무것도
              // 안 그려진다(srcIn) — 불투명 배경을 가진 공용 스켈레톤을 쓴다.
              loading: () => ListView(
                controller: scroll,
                children: const [SkeletonListLoading(itemCount: 3)],
              ),
              error: (e, _) => Center(
                  child: Text('community_comments_error'.tr(),
                      style: glass.tileStatus)),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text('community_comments_empty'.tr(),
                          style: glass.tileStatus))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final name = c.authorName.isEmpty
                            ? 'community_author_unknown'.tr()
                            : c.authorName;
                        return ListTile(
                          // 타인 댓글은 길게 눌러 신고 (Apple 1.2, Task 11).
                          onLongPress: c.authorId == myId
                              ? null
                              : () => showReportReasonsSheet(
                                  context, (reason) => _reportComment(c.id, reason)),
                          // AccountAvatar는 onPressed·tooltip 필수 시그니처 —
                          // 댓글 아바타는 눌러도 갈 곳이 없어 no-op로 둔다.
                          leading: AccountAvatar(
                            tooltip: name,
                            onPressed: () {},
                            displayName: c.authorName,
                            imageUrl: c.authorAvatarUrl,
                          ),
                          title: Text(name,
                              style: glass.tileTitle.copyWith(fontSize: 12)),
                          subtitle: Text(c.body,
                              style: glass.tileStatus
                                  .copyWith(color: glass.textPrimary)),
                          trailing: c.authorId == myId
                              ? IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: glass.textTertiary),
                                  onPressed: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    try {
                                      await ref
                                          .read(communityRepositoryProvider)
                                          .deleteComment(c.id);
                                      if (!mounted) return;
                                      ref.invalidate(
                                          commentsProvider(widget.postId));
                                    } catch (_) {
                                      messenger.showSnackBar(SnackBar(
                                          content: Text(
                                              'community_comment_delete_failed'
                                                  .tr())));
                                    }
                                  },
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      hintText: 'community_comment_hint'.tr(),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: glass.activeTile),
                  onPressed: _sending ? null : _send,
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
