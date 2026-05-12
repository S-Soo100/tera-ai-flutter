import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/safe_hive.dart';
import '../domain/cached_video.dart';

class VideoCacheRepository {
  static const _boxName = 'video_cache';
  static const _subdir = 'clip_cache';
  static const int maxBytes = 1024 * 1024 * 1024; // 1GB

  Box<CachedVideo> get _box => Hive.box<CachedVideo>(_boxName);

  /// 동시 다운로드 race 방지: 같은 clipId 여러 호출 → 단일 Future 공유.
  final Map<String, Future<File>> _inFlight = {};

  static Future<void> init() async {
    Hive.registerAdapter(CachedVideoAdapter());
    await openBoxSafely<CachedVideo>(_boxName);
    // 캐시 서브디렉토리 미리 생성
    final dir = await _cacheSubdir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  static Future<Directory> _cacheSubdir() async {
    final base = await getApplicationCacheDirectory();
    return Directory('${base.path}/$_subdir');
  }

  /// 캐시 hit이면 File 반환 + lastAccessedAt 갱신. miss면 null.
  /// Hive 메타가 있는데 파일이 사라진 경우(OS 캐시 정리) → 메타 삭제 후 null.
  Future<File?> getCached(String clipId) async {
    final meta = _box.get(clipId);
    if (meta == null) return null;

    final file = File(meta.filePath);
    if (!file.existsSync()) {
      await meta.delete(); // 메타 정합성 복구
      return null;
    }

    meta.lastAccessedAt = DateTime.now();
    await meta.save();
    return file;
  }

  /// presigned URL에서 mp4 다운로드 → cache dir 저장 → Hive 메타 INSERT.
  /// 같은 clipId 동시 호출 시 단일 Future 공유.
  Future<File> downloadAndCache(String clipId, String presignedUrl) async {
    final existing = _inFlight[clipId];
    if (existing != null) return existing;

    final future = _doDownload(clipId, presignedUrl);
    _inFlight[clipId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(clipId);
    }
  }

  Future<File> _doDownload(String clipId, String presignedUrl) async {
    final resp = await http.get(Uri.parse(presignedUrl));
    if (resp.statusCode != 200) {
      throw Exception('Video download failed: ${resp.statusCode}');
    }
    final bytes = resp.bodyBytes;

    final dir = await _cacheSubdir();
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final filePath = '${dir.path}/$clipId.mp4';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // 1GB 한도 사전 정리
    await _evictLRU(bytes.length);

    final meta = CachedVideo(
      clipId: clipId,
      filePath: filePath,
      sizeBytes: bytes.length,
      downloadedAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );
    await _box.put(clipId, meta);

    return file;
  }

  /// 새 파일 추가 시 한도 초과면 lastAccessedAt 오래된 것부터 삭제.
  Future<void> _evictLRU(int incomingBytes) async {
    var totalBytes = await getTotalSize() + incomingBytes;
    if (totalBytes <= maxBytes) return;

    // lastAccessedAt 오름차순 정렬 (오래된 게 먼저)
    final entries = _box.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    for (final entry in entries) {
      if (totalBytes <= maxBytes) break;
      final file = File(entry.filePath);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // file.delete() 실패만 흡수 — Hive 메타 삭제는 계속 진행
        }
      }
      totalBytes -= entry.sizeBytes;
      await entry.delete(); // Hive 메타 삭제 실패는 흡수 금지
    }
  }

  Future<int> getTotalSize() async {
    return _box.values.fold<int>(0, (sum, v) => sum + v.sizeBytes);
  }
}
