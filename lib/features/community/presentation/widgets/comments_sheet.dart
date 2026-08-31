import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/community_post.dart';
import '../community_providers.dart';

/// 댓글 시트 — 피드 위에 떠서 맥락 유지 (시안 ④). 닫히면 피드 refresh로 카운트 수렴.
Future<void> showCommentsSheet(
    BuildContext context, WidgetRef ref, CommunityPost post) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CommentsSheet(postId: post.id),
  );
  ref.read(communityFeedProvider.notifier).refresh();
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
    setState(() => _sending = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .addComment(widget.postId, body);
      _input.clear();
      ref.invalidate(commentsProvider(widget.postId));
    } finally {
      if (mounted) setState(() => _sending = false);
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
              loading: () => Shimmer.fromColors(
                baseColor: glass.skeletonBase,
                highlightColor: glass.skeletonHighlight,
                child: ListView(
                  controller: scroll,
                  children: [
                    for (var i = 0; i < 3; i++)
                      const ListTile(
                          title: SizedBox(height: 14),
                          subtitle: SizedBox(height: 12)),
                  ],
                ),
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
                                    await ref
                                        .read(communityRepositoryProvider)
                                        .deleteComment(c.id);
                                    ref.invalidate(
                                        commentsProvider(widget.postId));
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
