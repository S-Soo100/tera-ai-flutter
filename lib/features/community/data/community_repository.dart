import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community_comment.dart';
import '../domain/community_post.dart';

typedef PublicProfile = ({String name, String? avatarUrl});

/// posts row + 별도 조회한 프로필/내 좋아요를 화면 모델로 병합.
/// public_profiles는 FK가 auth.users 경유라 PostgREST embed가 안 돼
/// 병합을 클라에서 한다 — 네트워크 없는 순수 함수로 분리해 테스트.
List<CommunityPost> mergeFeedRows({
  required List<CommunityPost> posts,
  required Map<String, PublicProfile> profiles,
  required Set<String> myLikedPostIds,
}) {
  return [
    for (final p in posts)
      p.copyWith(
        authorName: profiles[p.authorId]?.name ?? '',
        authorAvatarUrl: profiles[p.authorId]?.avatarUrl,
        likedByMe: myLikedPostIds.contains(p.id),
      ),
  ];
}

/// 커뮤니티 피드/댓글/좋아요 — Supabase 직결(RLS: 읽기 전체·쓰기 본인).
class CommunityRepository {
  CommunityRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;
  static const _bucket = 'community-media';
  static const signedUrlTtlSec = 3600;

  String? get _uid => _supabase.auth.currentUser?.id;

  /// 쓰기 경로의 로그인 강제. 커뮤니티는 비로그인 열람 허용(kPublicPaths)이라
  /// uid 없는 쓰기를 조용히 삼키면 "접수됐어요" 같은 거짓 성공 안내가 된다 —
  /// 던져서 호출부의 실패 UI로 보낸다.
  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw StateError('community write requires sign-in');
    return uid;
  }

  /// 피드 한 페이지 (최신순). offset 기반 range 페이지네이션.
  Future<List<CommunityPost>> listPosts({int offset = 0, int limit = 20}) async {
    final rows = await _supabase
        .from('community_posts')
        .select('*, community_likes(count), community_comments(count)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final posts = (rows as List)
        .map((r) => CommunityPost.fromJson(r as Map<String, dynamic>))
        .toList();
    if (posts.isEmpty) return posts;

    final authorIds = posts.map((p) => p.authorId).toSet().toList();
    final postIds = posts.map((p) => p.id).toList();
    final results = await Future.wait([
      _fetchProfiles(authorIds),
      _fetchMyLikes(postIds),
    ]);
    return mergeFeedRows(
      posts: posts,
      profiles: results[0] as Map<String, PublicProfile>,
      myLikedPostIds: results[1] as Set<String>,
    );
  }

  /// 특정 작성자의 게시물 (모아보기, Task 13). listPosts와 같은 병합 로직.
  Future<List<CommunityPost>> listPostsByAuthor(String authorId,
      {int offset = 0, int limit = 30}) async {
    final rows = await _supabase
        .from('community_posts')
        .select('*, community_likes(count), community_comments(count)')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final posts = (rows as List)
        .map((r) => CommunityPost.fromJson(r as Map<String, dynamic>))
        .toList();
    if (posts.isEmpty) return posts;
    final profiles = await _fetchProfiles([authorId]);
    final likes = await _fetchMyLikes(posts.map((p) => p.id).toList());
    return mergeFeedRows(
        posts: posts, profiles: profiles, myLikedPostIds: likes);
  }

  Future<CommunityPost?> getPost(String id) async {
    final rows = await _supabase
        .from('community_posts')
        .select('*, community_likes(count), community_comments(count)')
        .eq('id', id)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final post = CommunityPost.fromJson(list.first as Map<String, dynamic>);
    final profiles = await _fetchProfiles([post.authorId]);
    final likes = await _fetchMyLikes([post.id]);
    return mergeFeedRows(
            posts: [post], profiles: profiles, myLikedPostIds: likes)
        .single;
  }

  Future<Map<String, PublicProfile>> _fetchProfiles(List<String> ids) async {
    try {
      final rows = await _supabase
          .from('public_profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', ids);
      return {
        for (final r in rows as List)
          (r as Map)['id'] as String: (
            name: (r['display_name'] as String?) ?? '',
            avatarUrl: r['avatar_url'] as String?,
          ),
      };
    } catch (_) {
      return {}; // 프로필 조회 실패는 피드를 막지 않는다 — 이니셜 폴백
    }
  }

  Future<Set<String>> _fetchMyLikes(List<String> postIds) async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _supabase
          .from('community_likes')
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', postIds);
      return {for (final r in rows as List) (r as Map)['post_id'] as String};
    } catch (_) {
      return {};
    }
  }

  /// like=true면 좋아요, false면 해제. upsert/조건 delete라 중복 탭에 안전.
  Future<void> setLike(String postId, bool like) async {
    final uid = _requireUid();
    if (like) {
      await _supabase
          .from('community_likes')
          .upsert({'post_id': postId, 'user_id': uid});
    } else {
      await _supabase
          .from('community_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  Future<List<CommunityComment>> listComments(String postId) async {
    final rows = await _supabase
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    final comments = (rows as List)
        .map((r) => CommunityComment.fromJson(r as Map<String, dynamic>))
        .toList();
    if (comments.isEmpty) return comments;
    final profiles =
        await _fetchProfiles(comments.map((c) => c.authorId).toSet().toList());
    return [
      for (final c in comments)
        c.withAuthor(
            profiles[c.authorId]?.name ?? '', profiles[c.authorId]?.avatarUrl),
    ];
  }

  Future<void> addComment(String postId, String body) async {
    final uid = _requireUid();
    await _supabase.from('community_comments').insert({
      'post_id': postId,
      'author_id': uid,
      'body': body,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _supabase.from('community_comments').delete().eq('id', commentId);
  }

  /// 게시물 삭제 = row 삭제(likes/comments는 FK CASCADE) + Storage 복사본 정리.
  /// Storage 삭제는 best-effort — row가 지워지면 파일은 접근 불가 고아일 뿐.
  Future<void> deletePost(CommunityPost post) async {
    await _supabase.from('community_posts').delete().eq('id', post.id);
    final paths = [
      post.videoPath,
      if (post.thumbnailPath != null) post.thumbnailPath!,
      if (post.petPhotoPath != null) post.petPhotoPath!,
    ];
    try {
      await _supabase.storage.from(_bucket).remove(paths);
    } catch (_) {}
  }

  /// 내가 차단한 유저 id 집합. 실패 시 빈 집합(피드를 막지 않는다).
  Future<Set<String>> blockedUserIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _supabase
          .from('community_blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return {
        for (final r in rows as List) (r as Map)['blocked_id'] as String
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> blockUser(String userId) async {
    final uid = _requireUid();
    await _supabase
        .from('community_blocks')
        .upsert({'blocker_id': uid, 'blocked_id': userId});
  }

  Future<void> unblockUser(String userId) async {
    final uid = _requireUid();
    await _supabase
        .from('community_blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', userId);
  }

  /// 차단 목록 화면용 — 차단 유저의 표시 이름·아바타(public_profiles).
  Future<List<({String id, String name, String? avatarUrl})>>
      blockedProfiles() async {
    final ids = (await blockedUserIds()).toList();
    if (ids.isEmpty) return [];
    final profiles = await _fetchProfiles(ids);
    return [
      for (final id in ids)
        (
          id: id,
          name: profiles[id]?.name ?? '',
          avatarUrl: profiles[id]?.avatarUrl,
        ),
    ];
  }

  /// 신고 접수 (Apple 1.2). targetKind: 'post' | 'comment'.
  Future<void> report({
    required String targetKind,
    required String targetId,
    required String reason,
    String? detail,
  }) async {
    final uid = _requireUid();
    await _supabase.from('community_reports').insert({
      'reporter_id': uid,
      'target_kind': targetKind,
      'target_id': targetId,
      'reason': reason,
      'detail': detail,
    });
  }

  /// 피드 한 페이지의 썸네일·크레 사진 signed URL 일괄 발급. path → url.
  Future<Map<String, String>> signedImageUrls(List<CommunityPost> posts) {
    return signedUrls(<String>{
      for (final p in posts) ...[
        if (p.thumbnailPath != null) p.thumbnailPath!,
        if (p.petPhotoPath != null) p.petPhotoPath!,
      ],
    }.toList());
  }

  /// storage 경로 목록 → signed URL 일괄 발급 (path → url). 실패 시 빈 맵 —
  /// 이미지 로드는 화면을 막지 않는다(카드는 아이콘 폴백).
  Future<Map<String, String>> signedUrls(List<String> paths) async {
    if (paths.isEmpty) return {};
    try {
      final signed = await _supabase.storage
          .from(_bucket)
          .createSignedUrls(paths, signedUrlTtlSec);
      // storage_client 2.5.1의 SignedUrl.path는 non-nullable — null 분기 불필요.
      return {for (final s in signed) s.path: s.signedUrl};
    } catch (_) {
      return {};
    }
  }

  Future<String> signedVideoUrl(String videoPath) async {
    return _supabase.storage
        .from(_bucket)
        .createSignedUrl(videoPath, signedUrlTtlSec);
  }
}
