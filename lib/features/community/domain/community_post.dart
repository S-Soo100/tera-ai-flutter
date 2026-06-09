enum CommunityCategory {
  all('all'),
  notice('notice'),
  wiki('wiki'),
  qna('qna'),
  free('free');

  const CommunityCategory(this.id);
  final String id;

  static CommunityCategory fromId(String id) {
    return CommunityCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => CommunityCategory.all,
    );
  }
}

class CommunityPost {
  final String id;
  final CommunityCategory category;
  final String title;
  final String authorName;
  final DateTime createdAt;
  final int commentCount;

  const CommunityPost({
    required this.id,
    required this.category,
    required this.title,
    required this.authorName,
    required this.createdAt,
    required this.commentCount,
  });
}
