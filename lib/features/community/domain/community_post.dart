import '../../../shared/domain/num_format.dart';

/// "n살 모프 여아·남아·아가" 감성 표기 (시안 확정 2026-08-29).
/// 빈 조각은 건너뛰고 이어 붙인다. 조각이 하나도 없으면 null.
/// 1살 미만은 "n개월", 생후 1개월 미만·birthDate null은 나이 생략.
/// sex는 pets.sex 값('female'/'male'/'unknown'). null/그 외 값 = 미구분(아가).
String? petTagLabel({
  String? morph,
  String? sex,
  DateTime? birthDate,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  String? age;
  if (birthDate != null && !birthDate.isAfter(ref)) {
    var months = (ref.year - birthDate.year) * 12 + ref.month - birthDate.month;
    if (ref.day < birthDate.day) months -= 1;
    if (months >= 12) {
      age = '${months ~/ 12}살';
    } else if (months >= 1) {
      age = '$months개월';
    }
  }
  final sexLabel = switch (sex) {
    'female' => '여아',
    'male' => '남아',
    'unknown' => '아가',
    _ => sex == null ? null : '아가',
  };
  final parts = [age, morph, sexLabel].whereType<String>().toList();
  return parts.isEmpty ? null : parts.join(' ');
}

/// PostgREST embedded count(`[{count: n}]`) → int. 형태가 다르면 0.
int embeddedCount(dynamic v) {
  if (v is List && v.isNotEmpty && v.first is Map) {
    return (v.first as Map)['count'] as int? ?? 0;
  }
  return 0;
}

/// community_posts row + 작성자(public_profiles) + 카운트 + 내 좋아요.
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName; // public_profiles 병합. 미로드 시 ''(이니셜 폴백)
  final String? authorAvatarUrl;
  final String? caption;
  final String videoPath; // community-media 내 경로
  final String? thumbnailPath;
  final String? sourceClipId;
  final double? durationSec;
  final String? action; // 행동 분류 스냅샷
  final String? petName;
  final String? petMorph;
  final String? petSex;
  final DateTime? petBirthDate;
  final String? petPhotoPath;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorAvatarUrl,
    this.caption,
    required this.videoPath,
    this.thumbnailPath,
    this.sourceClipId,
    this.durationSec,
    this.action,
    this.petName,
    this.petMorph,
    this.petSex,
    this.petBirthDate,
    this.petPhotoPath,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  /// 게시물의 크레 꼬리표. 크레 미연결 게시물이면 null.
  String? get petTag =>
      petTagLabel(morph: petMorph, sex: petSex, birthDate: petBirthDate);

  CommunityPost copyWith({
    String? authorName,
    String? authorAvatarUrl,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
  }) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        authorName: authorName ?? this.authorName,
        authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
        caption: caption,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        sourceClipId: sourceClipId,
        durationSec: durationSec,
        action: action,
        petName: petName,
        petMorph: petMorph,
        petSex: petSex,
        petBirthDate: petBirthDate,
        petPhotoPath: petPhotoPath,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    return CommunityPost(
      id: j['id'] as String,
      authorId: j['author_id'] as String,
      caption: j['caption'] as String?,
      videoPath: j['video_path'] as String,
      thumbnailPath: j['thumbnail_path'] as String?,
      sourceClipId: j['source_clip_id'] as String?,
      durationSec: (j['duration_sec'] as num?)?.toDouble(),
      action: j['action'] as String?,
      petName: j['pet_name'] as String?,
      petMorph: j['pet_morph'] as String?,
      petSex: j['pet_sex'] as String?,
      // DATE 컬럼은 'YYYY-MM-DD' — 시각 개념이 없어 로컬 변환 없이 파싱.
      petBirthDate: j['pet_birth_date'] != null
          ? DateTime.tryParse(j['pet_birth_date'] as String)
          : null,
      petPhotoPath: j['pet_photo_path'] as String?,
      createdAt: parseLocalDateTime(j['created_at']) ?? DateTime.now(),
      likeCount: embeddedCount(j['community_likes']),
      commentCount: embeddedCount(j['community_comments']),
    );
  }
}
