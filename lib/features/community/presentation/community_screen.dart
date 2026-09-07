import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_header.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/supabase_module_providers.dart'
    show nowTickProvider;
import '../../profile/presentation/profile_providers.dart';
import '../domain/community_post.dart';
import 'community_providers.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/post_card.dart';

/// 커뮤니티 탭 = 크레캠 클립 공유 피드 (2026-08-29 리뉴얼).
/// 구 카테고리 게시판(공지/QnA/자유)은 폐기 — 위키 진입 카드만 유지(§4.5).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent * 0.8) {
        ref.read(communityFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(communityFeedProvider);
    final imageUrls = ref.watch(feedImageUrlsProvider).valueOrNull ?? const {};
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final myId = ref.watch(currentUserProvider.select((u) => u?.id));
    // 1분 틱 — 카드의 "N분 전"이 멈춰 있지 않게 리빌드를 건다(time_ago.dart).
    final now = ref.watch(nowTickProvider).valueOrNull;
    final glass = context.glass;

    return GlassTabShell(
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassTabHeader(
            title: 'community_title'.tr(),
            actions: [
              AccountAvatar(
                tooltip: 'home_account'.tr(),
                imageUrl: profile?.avatarUrl,
                displayName: profile?.displayName,
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(communityFeedProvider.notifier).refresh(),
              child: feed.when(
                loading: () => _FeedSkeleton(glass: glass),
                error: (e, _) => _ErrorState(
                    onRetry: () =>
                        ref.read(communityFeedProvider.notifier).refresh()),
                data: (posts) => ListView(
                  controller: _scroll,
                  padding: glassDockListPadding(context),
                  children: [
                    const _NoticeBanner(),
                    if (posts.isEmpty)
                      _EmptyFeed()
                    else
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppStyles.spacing16,
                              AppStyles.spacing12,
                              AppStyles.spacing16,
                              0),
                          child: PostCard(
                            post: post,
                            now: now,
                            thumbnailUrl: post.thumbnailPath == null
                                ? null
                                : imageUrls[post.thumbnailPath],
                            petPhotoUrl: post.petPhotoPath == null
                                ? null
                                : imageUrls[post.petPhotoPath],
                            onPlay: () =>
                                context.push('/community-player/${post.id}'),
                            onToggleLike: () => ref
                                .read(communityFeedProvider.notifier)
                                .toggleLike(post.id),
                            onOpenComments: () =>
                                showCommentsSheet(context, ref, post),
                            isMine: post.authorId == myId,
                            onDelete: post.authorId == myId
                                ? () => _confirmDelete(post)
                                : null,
                            onReport: (reason) => _reportPost(post, reason),
                            onBlock: () => _confirmBlock(post),
                            onOpenAuthor: () => context
                                .push('/community-user/${post.authorId}'),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ]),
        Positioned(
          right: 16,
          bottom: glassDockListPadding(context).bottom + 8,
          child: FloatingActionButton(
            backgroundColor: glass.activeTile,
            foregroundColor: glass.textOnActive,
            onPressed: () => context.push('/community-share'),
            child: const Icon(Icons.add),
          ),
        ),
      ]),
    );
  }

  Future<void> _reportPost(CommunityPost post, String reason) async {
    // async gap 전에 캡처 — 신고 완료 시점엔 context가 죽어 있을 수 있다.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityRepositoryProvider).report(
          targetKind: 'post', targetId: post.id, reason: reason);
      messenger.showSnackBar(
          SnackBar(content: Text('community_report_done'.tr())));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text('community_report_failed'.tr())));
    }
  }

  Future<void> _confirmBlock(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('community_block_user'.tr()),
        content: Text('community_block_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common_cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('community_block_user'.tr())),
        ],
      ),
    );
    if (ok == true && mounted) {
      final messenger = ScaffoldMessenger.of(context); // async gap 전에 캡처
      try {
        await ref
            .read(communityFeedProvider.notifier)
            .blockUser(post.authorId);
      } catch (_) {
        // 실패를 삼키면 카드가 남아 있는 이유를 알 길이 없다 — 신고와 동일 문법.
        messenger.showSnackBar(
            SnackBar(content: Text('community_block_failed'.tr())));
      }
    }
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('community_delete_post'.tr()),
        content: Text('community_delete_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common_cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common_delete'.tr())),
        ],
      ),
    );
    if (ok == true && mounted) {
      final messenger = ScaffoldMessenger.of(context); // async gap 전에 캡처
      try {
        await ref.read(communityFeedProvider.notifier).deletePost(post);
      } catch (_) {
        messenger.showSnackBar(
            SnackBar(content: Text('community_delete_failed'.tr())));
      }
    }
  }
}

/// 운영자 공지 배너 — 최신 1건, 0건이면 아무것도 그리지 않는다 (Task 10).
/// 탭하면 본문 다이얼로그(본문 없는 공지는 탭 불가).
class _NoticeBanner extends ConsumerWidget {
  const _NoticeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(latestNoticeProvider).valueOrNull;
    if (notice == null) return const SizedBox.shrink();
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyles.spacing16, 0,
          AppStyles.spacing16, AppStyles.spacing12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: notice.body == null
              ? null
              : () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(notice.title),
                      content: Text(notice.body!),
                    ),
                  ),
          child: Row(children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: glass.activeTile),
            ),
            const SizedBox(width: 10),
            Text('community_notice_label'.tr(), style: glass.labelCaps),
            const SizedBox(width: 8),
            Expanded(
              child: Text(notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: glass.tileTitle.copyWith(fontSize: 12.5)),
            ),
            Icon(Icons.chevron_right, size: 16, color: glass.textTertiary),
          ]),
        ),
      ),
    );
  }
}

/// 빈 피드 — "준비 중"이 아니라 첫 공유 유도 (시안 확정).
class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
      child: Column(children: [
        Icon(Icons.video_library_outlined, size: 40, color: glass.textTertiary),
        const SizedBox(height: 12),
        Text('community_empty_title'.tr(),
            style: glass.tileTitle, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('community_empty_body'.tr(),
            style: glass.tileStatus, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('community_feed_error'.tr(), style: context.glass.tileStatus),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
      ]),
    );
  }
}

/// 로딩 스켈레톤 — CircularProgressIndicator 금지 규칙.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.glass});
  final GlassPalette glass;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: glass.skeletonBase,
      highlightColor: glass.skeletonHighlight,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppStyles.spacing16),
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppStyles.spacing12),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: glass.overlay,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 위키 진입 카드(_WikiShortcutCard)는 2026-09-02 PRD 재설계로 제거 —
// 위키 라우트·진입점 폐지(계획서 Task 2).
