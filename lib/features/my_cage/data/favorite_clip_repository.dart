import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/safe_hive.dart';
import '../domain/favorite_clip.dart';
import '../domain/motion_clip.dart';
import 'motion_clip_repository.dart';

/// 즐겨찾기 = 로컬 Hive 메타 + 앱 문서 디렉토리 mp4 영구보관(캐시 LRU와 분리).
/// Supabase `clip_favorites`(owner_id, clip_id)를 durable 플래그로 써서
/// 재설치·기기변경에도 즐겨찾기가 복원된다. add/remove 시 클라우드에 즉시 push,
/// 즐겨찾기 탭 진입 시 [syncFromCloud]로 누락분 pull. 계정 격리는 ownerId로 자체 처리.
/// main()에서 [init] 선 실행.
class FavoriteClipRepository {
  FavoriteClipRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;
  static const _boxName = 'favorite_clips';
  static const _subdir = 'favorite_clips';
  static const _table = 'clip_favorites';

  Box<FavoriteClip> get _box => Hive.box<FavoriteClip>(_boxName);

  String? get _uid => _supabase.auth.currentUser?.id;

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

  bool isFavorite(String clipId) {
    final m = _box.get(clipId);
    return m != null && m.ownerId == _uid;
  }

  /// 카메라의 즐겨찾기 목록(최근 저장순, 현재 계정 소유분만).
  List<FavoriteClip> listByCamera(String cameraId) {
    final uid = _uid;
    return _box.values
        .where((f) => f.ownerId == uid && f.cameraId == cameraId)
        .toList()
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
  }

  /// 로컬 mp4 파일(오프라인 재생용, 현재 계정 소유분만). 없으면 null.
  File? getLocalFile(String clipId) {
    final m = _box.get(clipId);
    if (m == null || m.ownerId != _uid) return null;
    final f = File(m.filePath);
    return f.existsSync() ? f : null;
  }

  /// 즐겨찾기 메타(오프라인 일시/카메라 등, 현재 계정 소유분만). 없으면 null.
  FavoriteClip? getMeta(String clipId) {
    final m = _box.get(clipId);
    return (m != null && m.ownerId == _uid) ? m : null;
  }

  /// 즐겨찾기 추가 = presigned URL로 mp4 다운로드 → 문서 디렉토리 저장 → 메타 INSERT
  /// → 클라우드 upsert(best-effort).
  Future<void> add(MotionClip clip, String presignedUrl) async {
    if (_uid == null) return;
    if (isFavorite(clip.id)) return;
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
        ownerId: _uid ?? '',
      ),
    );
    final uid = _uid;
    if (uid != null) {
      try {
        await _supabase
            .from(_table)
            .upsert({'owner_id': uid, 'clip_id': clip.id});
      } catch (_) {
        /* 오프라인 등 — 다음 sync에서 재push */
      }
    }
  }

  /// 즐겨찾기 해제 = 로컬 파일 삭제 + 메타 삭제 + 클라우드 삭제(best-effort).
  /// 해제된 클립의 cameraId 반환(목록 갱신용).
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
    final uid = _uid;
    if (uid != null) {
      try {
        await _supabase
            .from(_table)
            .delete()
            .eq('owner_id', uid)
            .eq('clip_id', clipId);
      } catch (_) {}
    }
    return cameraId;
  }

  /// 클라우드 즐겨찾기 clip_id 집합(현재 계정). 실패 시 빈 집합.
  Future<Set<String>> _cloudClipIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows =
          await _supabase.from(_table).select('clip_id').eq('owner_id', uid);
      return {for (final r in rows as List) (r as Map)['clip_id'] as String};
    } catch (_) {
      return {};
    }
  }

  /// cloud↔local 동기화. push: 로컬만 있는 것 → 클라우드. pull: 클라우드만 있는 것
  /// → metadata+mp4 다운로드해 로컬 보관. best-effort(개별 실패 skip).
  /// [motionRepo]로 getById/getPlaybackUrl 수행.
  Future<void> syncFromCloud(MotionClipRepository motionRepo) async {
    final uid = _uid;
    if (uid == null) return;
    final cloud = await _cloudClipIds();
    final localIds = _box.values
        .where((f) => f.ownerId == uid)
        .map((f) => f.clipId)
        .toSet();

    // push: 로컬에만 있는 것
    for (final id in localIds.difference(cloud)) {
      try {
        await _supabase.from(_table).upsert({'owner_id': uid, 'clip_id': id});
      } catch (_) {}
    }
    // pull: 클라우드에만 있는 것 → 다운로드
    for (final id in cloud.difference(localIds)) {
      try {
        final clip = await motionRepo.getById(id);
        if (clip == null) continue;
        final url = await motionRepo.getPlaybackUrl(id);
        await add(clip, url); // add가 다시 upsert하지만 idempotent
      } catch (_) {
        /* 개별 실패 skip */
      }
    }
  }
}
