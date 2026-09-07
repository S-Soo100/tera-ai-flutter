import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/community/data/community_repository.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';

void main() {
  final base = CommunityPost(
    id: 'p1',
    authorId: 'u1',
    videoPath: 'u1/posts/p1.mp4',
    createdAt: DateTime(2026, 8, 28),
  );

  test('작성자 프로필·내 좋아요 병합', () {
    final merged = mergeFeedRows(
      posts: [base],
      profiles: {'u1': (name: '게코집사', avatarUrl: null)},
      myLikedPostIds: {'p1'},
    );
    expect(merged.single.authorName, '게코집사');
    expect(merged.single.likedByMe, true);
  });

  test('프로필 없는 작성자는 빈 이름(이니셜 폴백)', () {
    final merged =
        mergeFeedRows(posts: [base], profiles: {}, myLikedPostIds: {});
    expect(merged.single.authorName, '');
    expect(merged.single.likedByMe, false);
  });
}
