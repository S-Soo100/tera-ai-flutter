import '../domain/community_post.dart';

/// 커뮤니티 게시글 저장소.
///
/// **아직 저장소가 없다.** Supabase에 커뮤니티 계열 테이블이 하나도 없어
/// (2026-08-08 확인) 읽을 곳도 쓸 곳도 없다. 테이블 + RLS 마이그레이션이
/// 선행돼야 하며, 공유 프로덕션 DB 스키마 변경이라 임의로 만들지 않는다.
///
/// ⚠️ **가짜 글을 채워 넣지 말 것.** 예전엔 지어낸 제목·작성자·댓글 수를
/// 5건 넣어뒀는데(`_seedPosts`), 화면은 그럴듯했지만 **사용자에게는 실재하는
/// 커뮤니티로 보였다.** 없는 것은 없다고 말하는 편이 낫다 — 화면은
/// `PendingSection`으로 무엇이 준비 중인지 밝힌다.
class CommunityRepository {
  /// 테이블이 생기기 전까지 항상 비어 있다.
  List<CommunityPost> getPosts({CommunityCategory? category}) => const [];
}
