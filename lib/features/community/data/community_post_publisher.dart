import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../my_cage/data/camera_exceptions.dart';
import '../../my_cage/data/favorite_clip_repository.dart';
import '../../my_cage/data/motion_clip_repository.dart';
import '../../my_cage/domain/favorite_clip.dart';
import '../../my_pets/domain/pet.dart';

/// 원본 클립이 R2 30일 보존기한으로 만료됨 — 사용자 안내용 (회신 2026-08-31 §3).
class ClipExpiredException implements Exception {}

/// 게시 = 스냅샷 복사 파이프라인.
/// 영상(로컬 mp4 우선) + 썸네일(terra presigned) + 크레 사진(로컬)을
/// community-media로 올리고 community_posts에 INSERT.
/// INSERT 실패 시 올린 객체를 지운다(고아 방지). 진행률은 0~1.
class CommunityPostPublisher {
  CommunityPostPublisher({
    required SupabaseClient supabase,
    required MotionClipRepository motionRepo,
    required FavoriteClipRepository favoriteRepo,
  })  : _supabase = supabase,
        _motionRepo = motionRepo,
        _favoriteRepo = favoriteRepo;

  final SupabaseClient _supabase;
  final MotionClipRepository _motionRepo;
  final FavoriteClipRepository _favoriteRepo;
  static const _bucket = 'community-media';

  Future<void> publish({
    required FavoriteClip fav,
    String? caption,
    Pet? pet,
    void Function(double progress)? onProgress,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    final postId = const Uuid().v4();
    final uploaded = <String>[];
    void report(double v) => onProgress?.call(v.clamp(0, 1));

    try {
      // 1) 영상 — 로컬 즐겨찾기 파일 우선, 유실 시 presigned 다운로드 폴백.
      //    로컬 유실 + 원본 만료(R2 30일 lifecycle) 조합의 404는 정상 케이스 —
      //    ClipExpiredException으로 구분해 화면이 안내한다 (회신 2026-08-31 §3).
      report(0.05);
      final local = _favoriteRepo.getLocalFile(fav.clipId);
      final Uint8List videoBytes;
      if (local != null) {
        videoBytes = await local.readAsBytes();
      } else {
        final String url;
        try {
          url = await _motionRepo.getPlaybackUrl(fav.clipId);
        } on BackendException catch (e) {
          if (e.statusCode == 404) throw ClipExpiredException();
          rethrow;
        }
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 404) throw ClipExpiredException();
        if (resp.statusCode != 200) {
          throw Exception('clip download failed: ${resp.statusCode}');
        }
        videoBytes = resp.bodyBytes;
      }
      final videoPath = '$uid/posts/$postId.mp4';
      await _supabase.storage.from(_bucket).uploadBinary(
            videoPath,
            videoBytes,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );
      uploaded.add(videoPath);
      report(0.6);

      // 2) 썸네일 — presigned GET, 404/조회 실패면 없이 진행(피드는 아이콘 폴백)
      String? thumbnailPath;
      String? thumbUrl;
      try {
        thumbUrl = await _motionRepo.getThumbnailUrl(fav.clipId);
      } catch (_) {
        thumbUrl = null; // 썸네일은 선택 — 실패가 게시를 막지 않는다
      }
      if (thumbUrl != null) {
        final resp = await http.get(Uri.parse(thumbUrl));
        if (resp.statusCode == 200) {
          thumbnailPath = '$uid/posts/$postId.jpg';
          await _supabase.storage.from(_bucket).uploadBinary(
                thumbnailPath,
                resp.bodyBytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );
          uploaded.add(thumbnailPath);
        }
      }
      report(0.75);

      // 3) 크레 사진 — 로컬 파일이 있을 때만
      String? petPhotoPath;
      final photo = pet?.photoPath;
      if (photo != null && File(photo).existsSync()) {
        petPhotoPath = '$uid/posts/${postId}_pet.jpg';
        await _supabase.storage.from(_bucket).uploadBinary(
              petPhotoPath,
              await File(photo).readAsBytes(),
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        uploaded.add(petPhotoPath);
      }
      report(0.85);

      // 4) 행동 라벨 스냅샷 (실패해도 게시는 계속)
      String? action;
      try {
        action = await _motionRepo.labelFor(fav.clipId);
      } catch (_) {}

      // 5) row INSERT
      await _supabase.from('community_posts').insert({
        'id': postId,
        'author_id': uid,
        'caption': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'source_clip_id': fav.clipId,
        'duration_sec': fav.durationSec,
        'action': action,
        'pet_name': pet?.name,
        'pet_morph': pet?.morph,
        'pet_sex': pet?.sex,
        'pet_birth_date':
            pet?.birthDate?.toIso8601String().substring(0, 10), // DATE
        'pet_photo_path': petPhotoPath,
      });
      report(1.0);
    } catch (e) {
      if (uploaded.isNotEmpty) {
        try {
          await _supabase.storage.from(_bucket).remove(uploaded);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
