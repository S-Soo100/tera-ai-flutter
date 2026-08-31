import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/glass_palette.dart';
import 'community_providers.dart';

/// 유저별 클립 모아보기 — 썸네일 3열 그리드, 타일 탭 = 재생.
class UserPostsScreen extends ConsumerWidget {
  const UserPostsScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final page = ref.watch(authorPostsProvider(userId));
    final urls = ref.watch(authorPostImageUrlsProvider(userId)).valueOrNull ??
        const <String, String>{};

    final name = page.valueOrNull
            ?.map((p) => p.authorName)
            .where((n) => n.isNotEmpty)
            .firstOrNull ??
        'community_author_unknown'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'community_user_posts_title'.tr(namedArgs: {'name': name})),
      ),
      body: page.when(
        loading: () => Shimmer.fromColors(
          baseColor: glass.skeletonBase,
          highlightColor: glass.skeletonHighlight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppStyles.spacing16),
            gridDelegate: _gridDelegate,
            itemCount: 9,
            itemBuilder: (_, __) => DecoratedBox(
              decoration: BoxDecoration(
                color: glass.overlay,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        error: (e, _) => Center(
            child: Text('community_feed_error'.tr(), style: glass.tileStatus)),
        data: (posts) => posts.isEmpty
            ? Center(
                child: Text('community_user_posts_empty'.tr(),
                    style: glass.tileStatus))
            : GridView.builder(
                padding: const EdgeInsets.all(AppStyles.spacing16),
                gridDelegate: _gridDelegate,
                itemCount: posts.length,
                itemBuilder: (context, i) {
                  final post = posts[i];
                  final thumb = post.thumbnailPath == null
                      ? null
                      : urls[post.thumbnailPath];
                  return InkWell(
                    onTap: () =>
                        context.push('/community-player/${post.id}'),
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: thumb != null
                          ? Image.network(thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fallback(glass))
                          : _fallback(glass),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    mainAxisSpacing: 6,
    crossAxisSpacing: 6,
  );

  Widget _fallback(GlassPalette glass) => ColoredBox(
        color: glass.overlayFaint,
        child: Icon(Icons.videocam_off_outlined,
            color: glass.textTertiary, size: 24),
      );
}
