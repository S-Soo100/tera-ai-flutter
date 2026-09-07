import '../../../shared/domain/num_format.dart';

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName; // public_profiles 병합
  final String? authorAvatarUrl;
  final String body;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName = '',
    this.authorAvatarUrl,
    required this.body,
    required this.createdAt,
  });

  CommunityComment withAuthor(String name, String? avatarUrl) =>
      CommunityComment(
        id: id,
        postId: postId,
        authorId: authorId,
        authorName: name,
        authorAvatarUrl: avatarUrl,
        body: body,
        createdAt: createdAt,
      );

  factory CommunityComment.fromJson(Map<String, dynamic> j) => CommunityComment(
        id: j['id'] as String,
        postId: j['post_id'] as String,
        authorId: j['author_id'] as String,
        body: j['body'] as String,
        createdAt: parseLocalDateTime(j['created_at']) ?? DateTime.now(),
      );
}
