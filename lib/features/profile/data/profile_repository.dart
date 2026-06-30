import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<UserProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile({
    String? displayName,
    String? experience,
    List<String>? preferredSpecies,
    String? timezone,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (experience != null) updates['experience'] = experience;
    if (preferredSpecies != null) updates['preferred_species'] = preferredSpecies;
    if (timezone != null) updates['timezone'] = timezone;

    await _client.from('user_profiles').update(updates).eq('id', userId);
  }

  Future<String?> uploadAvatar(File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final path = '$userId/avatar.jpg';
    await _client.storage.from('user-avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    // 캐시버스팅 쿼리 부착 → 같은 경로(upsert)로 덮어써도 URL이 바뀌어 CachedNetworkImage가 새 이미지를 받음
    final baseUrl = _client.storage.from('user-avatars').getPublicUrl(path);
    final url = '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('user_profiles')
        .update({'avatar_url': url, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);

    return url;
  }
}
