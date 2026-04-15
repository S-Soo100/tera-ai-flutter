import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/media_item.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(Supabase.instance.client);
});

class MediaRepository {
  final SupabaseClient _client;

  MediaRepository(this._client);

  Future<List<MediaItem>> getMedia(String petId) async {
    final data = await _client
        .from('media')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false);
    return data
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  Future<MediaItem> uploadPhoto({
    required String petId,
    required File file,
    String? eventId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final mediaId = const Uuid().v4();
    final path = '$userId/$petId/$mediaId.jpg';

    await _client.storage.from('pet-media').upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    final url = _client.storage.from('pet-media').getPublicUrl(path);
    final fileSize = await file.length();

    final data = await _client.from('media').insert({
      'pet_id': petId,
      if (eventId != null) 'event_id': eventId,
      'type': 'image',
      'url': url,
      'file_size': fileSize,
    }).select().single();

    return MediaItem.fromJson(data);
  }

  Future<void> deleteMedia(String mediaId) async {
    await _client.from('media').delete().eq('id', mediaId);
  }

  /// 펫 아바타 설정 (photoPath에 URL 저장)
  Future<String> uploadPetAvatar({
    required String petId,
    required File file,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final path = '$userId/$petId/avatar.jpg';
    await _client.storage.from('pet-media').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );

    return _client.storage.from('pet-media').getPublicUrl(path);
  }
}
