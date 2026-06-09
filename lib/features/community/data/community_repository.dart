import '../domain/community_post.dart';

class CommunityRepository {
  List<CommunityPost> _seedPosts() {
    final now = DateTime.now();
    return [
      CommunityPost(
        id: 'p1',
        category: CommunityCategory.qna,
        title: '베이비 슈푸 거부하는데 팁 있을까요?',
        authorName: '초보집사',
        createdAt: now.subtract(const Duration(minutes: 10)),
        commentCount: 5,
      ),
      CommunityPost(
        id: 'p2',
        category: CommunityCategory.qna,
        title: 'MBD 초기 증상인지 봐주세요 ㅠㅠ',
        authorName: '도리도리',
        createdAt: now.subtract(const Duration(hours: 1)),
        commentCount: 12,
      ),
      CommunityPost(
        id: 'p3',
        category: CommunityCategory.wiki,
        title: '적정 습도 유지하는 방법 총정리',
        authorName: '고인물',
        createdAt: now.subtract(const Duration(hours: 3)),
        commentCount: 24,
      ),
      CommunityPost(
        id: 'p4',
        category: CommunityCategory.notice,
        title: '커뮤니티 이용 규칙 안내',
        authorName: '운영자',
        createdAt: now.subtract(const Duration(days: 2)),
        commentCount: 0,
      ),
      CommunityPost(
        id: 'p5',
        category: CommunityCategory.free,
        title: '오늘 크레 처음으로 점프했어요',
        authorName: '찰떡맘',
        createdAt: now.subtract(const Duration(hours: 6)),
        commentCount: 3,
      ),
    ];
  }

  List<CommunityPost> getPosts({CommunityCategory? category}) {
    final posts = _seedPosts();
    if (category == null || category == CommunityCategory.all) {
      return posts;
    }
    return posts.where((p) => p.category == category).toList();
  }
}
