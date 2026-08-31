import 'dart:async';

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
  Set<String> _blocked = {};

  /// 서버에서 가져온 **누적 행 수** — 페이지 offset은 반드시 이 값을 쓴다.
  /// 화면 리스트 길이(차단 필터·삭제 반영 후)를 쓰면 필터된 만큼 창이 뒤로
  /// 밀려 이미 표시한 행을 다시 받아 중복 카드가 생긴다.
  int _fetchedCount = 0;

  /// loadMore 재진입 가드. `state.isLoading`은 여기서 못 쓴다 — loadMore는
  /// state를 loading으로 바꾸지 않아 await 동안에도 AsyncData가 유지된다.
  bool _loadingMore = false;

  @override
  Future<List<CommunityPost>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id)); // 3층 격리 ①
    _hasMore = true;
    _loadingMore = false;
    final repo = ref.read(communityRepositoryProvider);
    _blocked = await repo.blockedUserIds();
    final page = await repo.listPosts(limit: _pageSize);
    _fetchedCount = page.length;
    _hasMore = page.length == _pageSize;
    return page.where((p) => !_blocked.contains(p.authorId)).toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// 게시물 1건의 카운트·좋아요만 서버와 동기화. 댓글 시트가 닫힐 때 전체
  /// refresh를 부르면 loadMore로 쌓은 페이지가 전부 폐기되고 스크롤이
  /// 점프한다 — 그 자리를 이걸로 대신한다. 삭제된 글이면 목록에서 뺀다.
  Future<void> refreshPost(String postId) async {
    final updated =
        await ref.read(communityRepositoryProvider).getPost(postId);
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    if (updated == null) {
      state = AsyncData(current.where((p) => p.id != postId).toList());
      return;
    }
    state = AsyncData([...current]..[idx] = current[idx].copyWith(
        likeCount: updated.likeCount,
        commentCount: updated.commentCount,
        likedByMe: updated.likedByMe));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await ref
          .read(communityRepositoryProvider)
          .listPosts(offset: _fetchedCount, limit: _pageSize);
      // await 동안 refresh/계정 전환으로 state가 갈렸으면 이 페이지는 폐기 —
      // 옛 리스트 위에 append하면 리셋된 피드가 되살아난다.
      if (!identical(state.valueOrNull, current)) return;
      _fetchedCount += next.length;
      _hasMore = next.length == _pageSize;
      final existing = {for (final p in current) p.id};
      state = AsyncData([
        ...current,
        ...next.where((p) =>
            !_blocked.contains(p.authorId) && !existing.contains(p.id)),
      ]);
    } finally {
      _loadingMore = false;
    }
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

/// 피드 이미지(썸네일·크레 사진) signed URL — **경로 집합에만 종속**한다.
/// `communityFeedProvider.future`를 통째로 watch하면 좋아요 토글·삭제의
/// 리스트 재대입마다 전 페이지를 재발급하고, 토큰이 바뀐 URL은 ImageCache를
/// 전량 미스시킨다. 반대로 시간에는 반응해야 한다 — TTL(1h)보다 짧은
/// 50분마다 스스로 무효화해 만료 URL을 갱신한다(postVideoUrlProvider와 동일).
final feedImageUrlsProvider = FutureProvider<Map<String, String>>((ref) async {
  final timer = Timer(const Duration(minutes: 50), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  // 정렬된 경로 문자열이 캐시 키 — String ==라 내용이 같으면 재실행이 없다.
  final pathKey = await ref.watch(communityFeedProvider.selectAsync((posts) {
    final paths = <String>{
      for (final p in posts) ...[
        if (p.thumbnailPath != null) p.thumbnailPath!,
        if (p.petPhotoPath != null) p.petPhotoPath!,
      ],
    }.toList()
      ..sort();
    return paths.join('\n');
  }));
  final paths = pathKey.isEmpty ? const <String>[] : pathKey.split('\n');
  return ref.read(communityRepositoryProvider).signedUrls(paths);
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

// ── 피드 자동재생 (Task 14) ───────────────────────────────────────────────────

/// 자동재생 중인 게시물 id — **전역 1개**(동시 controller 1개 = OOM 방지).
final activeAutoplayPostIdProvider = StateProvider<String?>((ref) => null);

/// 게시물 영상 signed URL 캐시 — TTL 1h보다 짧은 50분 유지 후 폐기.
/// 카드가 보일 때마다 재발급하면 스크롤마다 storage 왕복이 생긴다.
final postVideoUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, videoPath) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 50), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(communityRepositoryProvider).signedVideoUrl(videoPath);
});

// ── 유저별 모아보기 (Task 13) ─────────────────────────────────────────────────

/// 작성자의 게시물 목록 (30건 — 모아보기 초기 규모엔 1페이지로 충분).
final authorPostsProvider = FutureProvider.autoDispose
    .family<List<CommunityPost>, String>((ref, authorId) {
  return ref.watch(communityRepositoryProvider).listPostsByAuthor(authorId);
});

/// 모아보기 그리드 썸네일 signed URL — 피드와 같은 일괄 발급 재사용.
final authorPostImageUrlsProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, authorId) async {
  final posts = await ref.watch(authorPostsProvider(authorId).future);
  return ref.read(communityRepositoryProvider).signedImageUrls(posts);
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
