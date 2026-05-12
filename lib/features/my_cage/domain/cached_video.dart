import 'package:hive/hive.dart';

part 'cached_video.g.dart';

@HiveType(typeId: 10)
class CachedVideo extends HiveObject {
  @HiveField(0)
  final String clipId;

  @HiveField(1)
  final String filePath;

  @HiveField(2)
  final int sizeBytes;

  @HiveField(3)
  final DateTime downloadedAt;

  @HiveField(4)
  DateTime lastAccessedAt;

  CachedVideo({
    required this.clipId,
    required this.filePath,
    required this.sizeBytes,
    required this.downloadedAt,
    required this.lastAccessedAt,
  });
}
