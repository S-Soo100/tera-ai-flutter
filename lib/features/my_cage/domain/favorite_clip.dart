import 'package:hive/hive.dart';

part 'favorite_clip.g.dart';

/// 즐겨찾기한 모션 클립(로컬 보관). mp4는 [filePath]에 앱 문서 디렉토리로 영구
/// 저장되어 presigned URL 만료·R2 삭제와 무관하게 오프라인 재생된다.
@HiveType(typeId: 11)
class FavoriteClip extends HiveObject {
  @HiveField(0)
  final String clipId;
  @HiveField(1)
  final String cameraId;
  @HiveField(2)
  final DateTime startedAt;
  @HiveField(3)
  final double durationSec;
  @HiveField(4)
  final String filePath;
  @HiveField(5)
  final int sizeBytes;
  @HiveField(6)
  final DateTime favoritedAt;

  FavoriteClip({
    required this.clipId,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    required this.filePath,
    required this.sizeBytes,
    required this.favoritedAt,
  });
}
