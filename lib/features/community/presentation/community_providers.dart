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

  /// 차단 유저 필터 (Task 12) — 앱 필터 결정(핸드오프 §3.3, RLS 서브쿼리 보류).
  /// offset은 서버 기준이라 필터 후 화면 개수가 페이지보다 적을 수 있음(허용).
  Set<String> _blocked = {};

  @override
  Future<List<CommunityPost>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id)); // 3층 격리 ①
    _hasMore = true;
    final repo = ref.read(communityRepositoryProvider);
    _blocked = await repo.blockedUserIds();
    final page = await repo.listPosts(limit: _pageSize);
    _hasMore = page.length == _pageSize;
    return page.where((p) => !_blocked.contains(p.authorId)).toList();
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
    state = AsyncData([
      ...current,
      ...next.where((p) => !_blocked.contains(p.authorId)),
    ]);
  }

  /// 유저 차단 → 피드 재조회(해당 유저 글 즉시 사라짐).
  Future<void> blockUser(String userId) async {
    await ref.read(communityRepositoryProvider).blockUser(userId);
    await refresh();
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
    .family<List<CommunityComment>, String>((ref, postId) async {
  final repo = ref.watch(communityRepositoryProvider);
  // 차단 유저 댓글 숨김 (Task 12) — 목록과 병행 로드.
  final results =
      await Future.wait([repo.listComments(postId), repo.blockedUserIds()]);
  final comments = results[0] as List<CommunityComment>;
  final blocked = results[1] as Set<String>;
  return comments.where((c) => !blocked.contains(c.authorId)).toList();
});

/// 차단 목록 화면(/profile/blocked)용 — 이름·아바타 포함.
final blockedProfilesProvider = FutureProvider.autoDispose<
    List<({String id, String name, String? avatarUrl})>>((ref) {
  return ref.watch(communityRepositoryProvider).blockedProfiles();
});

// ── 운영자 공지 (Task 10) — 앱은 읽기 전용, 작성은 대시보드 INSERT ─────────────

typedef CommunityNotice = ({String id, String title, String? body});

/// 최신 공지 1건. 0건이면 null — 배너 자체를 그리지 않는다(빈 카드 금지).
final latestNoticeProvider =
    FutureProvider.autoDispose<CommunityNotice?>((ref) async {
  final rows = await Supabase.instance.client
      .from('community_notices')
      .select('id, title, body')
      .order('created_at', ascending: false)
      .limit(1);
  final list = rows as List;
  if (list.isEmpty) return null;
  final r = list.first as Map<String, dynamic>;
  return (
    id: r['id'] as String,
    title: r['title'] as String,
    body: r['body'] as String?,
  );
});
