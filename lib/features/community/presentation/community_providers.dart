import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../data/community_post_publisher.dart';
import '../data/community_repository.dart';
import '../domain/community_comment.dart';
import '../domain/community_post.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(supabase: Supabase.instance.client),
);

final communityPublisherProvider = Provider<CommunityPostPublisher>(
  (ref) => CommunityPostPublisher(
    supabase: Supabase.instance.client,
    motionRepo: ref.watch(motionClipRepositoryProvider),
    favoriteRepo: ref.watch(favoriteClipRepositoryProvider),
  ),
);

const _pageSize = 20;

/// 피드 — offset 페이지네이션 + 낙관적 좋아요. 계정 전환 시 자동 리셋(userId watch).
class CommunityFeed extends AsyncNotifier<List<CommunityPost>> {
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<List<CommunityPost>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id)); // 3층 격리 ①
    _hasMore = true;
    final page =
        await ref.read(communityRepositoryProvider).listPosts(limit: _pageSize);
    _hasMore = page.length == _pageSize;
    return page;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !_hasMore || state.isLoading) return;
    final next = await ref
        .read(communityRepositoryProvider)
        .listPosts(offset: current.length, limit: _pageSize);
    _hasMore = next.length == _pageSize;
    state = AsyncData([...current, ...next]);
  }

  /// 낙관적 좋아요 — UI 먼저, 서버 실패 시 롤백.
  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = current[idx];
    final liked = !post.likedByMe;
    CommunityPost apply(CommunityPost p, bool v) =>
        p.copyWith(likedByMe: v, likeCount: p.likeCount + (v ? 1 : -1));
    state = AsyncData([...current]..[idx] = apply(post, liked));
    try {
      await ref.read(communityRepositoryProvider).setLike(postId, liked);
    } catch (_) {
      final rolled = state.valueOrNull;
      if (rolled == null) return;
      final i = rolled.indexWhere((p) => p.id == postId);
      if (i >= 0) {
        state = AsyncData([...rolled]..[i] = apply(rolled[i], !liked));
      }
    }
  }

  Future<void> deletePost(CommunityPost post) async {
    await ref.read(communityRepositoryProvider).deletePost(post);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((p) => p.id != post.id).toList());
    }
  }
}

final communityFeedProvider =
    AsyncNotifierProvider<CommunityFeed, List<CommunityPost>>(CommunityFeed.new);

/// 피드 이미지(썸네일·크레 사진) signed URL. 피드 데이터에 종속.
final feedImageUrlsProvider = FutureProvider<Map<String, String>>((ref) async {
  final posts = await ref.watch(communityFeedProvider.future);
  return ref.read(communityRepositoryProvider).signedImageUrls(posts);
});

final commentsProvider = FutureProvider.autoDispose
    .family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).listComments(postId);
});
