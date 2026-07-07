import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/safe_hive.dart';
import '../domain/favorite_clip.dart';
import '../domain/motion_clip.dart';

/// 즐겨찾기 = 로컬 Hive 메타 + 앱 문서 디렉토리 mp4 영구보관(캐시 LRU와 분리).
/// main()에서 [init] 선 실행.
class FavoriteClipRepository {
  static const _boxName = 'favorite_clips';
  static const _subdir = 'favorite_clips';

  Box<FavoriteClip> get _box => Hive.box<FavoriteClip>(_boxName);

  static Future<void> init() async {
    Hive.registerAdapter(FavoriteClipAdapter());
    await openBoxSafely<FavoriteClip>(_boxName);
    final dir = await _favDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  static Future<Directory> _favDir() async {
    final base = await getApplicationDocumentsDirectory(); // 영구(캐시 아님)
    return Directory('${base.path}/$_subdir');
  }

  bool isFavorite(String clipId) => _box.containsKey(clipId);

  /// 카메라의 즐겨찾기 목록(최근 저장순).
  List<FavoriteClip> listByCamera(String cameraId) {
    return _box.values.where((f) => f.cameraId == cameraId).toList()
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
  }

  /// 로컬 mp4 파일(오프라인 재생용). 없으면 null.
  File? getLocalFile(String clipId) {
    final meta = _box.get(clipId);
    if (meta == null) return null;
    final f = File(meta.filePath);
    return f.existsSync() ? f : null;
  }

  /// 즐겨찾기 추가 = presigned URL로 mp4 다운로드 → 문서 디렉토리 저장 → 메타 INSERT.
  Future<void> add(MotionClip clip, String presignedUrl) async {
    if (_box.containsKey(clip.id)) return;
    final resp = await http.get(Uri.parse(presignedUrl));
    if (resp.statusCode != 200) {
      throw Exception('favorite download failed: ${resp.statusCode}');
    }
    final bytes = resp.bodyBytes;
    final dir = await _favDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/${clip.id}.mp4';
    await File(path).writeAsBytes(bytes);
    await _box.put(
      clip.id,
      FavoriteClip(
        clipId: clip.id,
        cameraId: clip.cameraId,
        startedAt: clip.startedAt,
        durationSec: clip.durationSec,
        filePath: path,
        sizeBytes: bytes.length,
        favoritedAt: DateTime.now(),
      ),
    );
  }

  /// 즐겨찾기 해제 = 로컬 파일 삭제 + 메타 삭제. 해제된 클립의 cameraId 반환(목록 갱신용).
  Future<String?> remove(String clipId) async {
    final meta = _box.get(clipId);
    if (meta == null) return null;
    final cameraId = meta.cameraId;
    final f = File(meta.filePath);
    if (f.existsSync()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    await meta.delete();
    return cameraId;
  }
}
