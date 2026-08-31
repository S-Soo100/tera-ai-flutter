import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';

void main() {
  test('fromJson — 카운트·크레 스냅샷·UTC 변환', () {
    final p = CommunityPost.fromJson({
      'id': 'p1',
      'author_id': 'u1',
      'caption': '캡션',
      'video_path': 'u1/posts/p1.mp4',
      'thumbnail_path': 'u1/posts/p1.jpg',
      'source_clip_id': 'c1',
      'duration_sec': 24.0,
      'action': '탐색',
      'pet_name': '모카',
      'pet_morph': '릴리화이트',
      'pet_sex': 'female',
      'pet_birth_date': '2024-05-01',
      'pet_photo_path': 'u1/posts/p1_pet.jpg',
      'created_at': '2026-08-28T14:41:00Z', // UTC → 로컬(KST 23:41)
      'community_likes': [
        {'count': 12}
      ],
      'community_comments': [
        {'count': 4}
      ],
    });
    expect(p.likeCount, 12);
    expect(p.commentCount, 4);
    expect(p.petName, '모카');
    expect(p.createdAt.isUtc, false); // 로컬 변환 확인
    expect(p.petTag, isNotNull);
  });

  test('embeddedCount — 비정형 입력은 0', () {
    expect(embeddedCount(null), 0);
    expect(embeddedCount([]), 0);
    expect(embeddedCount('x'), 0);
  });
}
