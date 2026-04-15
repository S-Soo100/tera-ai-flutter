import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile();
});

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final repo = ref.watch(profileRepositoryProvider);
    return repo.getProfile();
  }

  Future<void> updateProfile({
    String? displayName,
    String? experience,
    List<String>? preferredSpecies,
  }) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.updateProfile(
      displayName: displayName,
      experience: experience,
      preferredSpecies: preferredSpecies,
    );
    ref.invalidateSelf();
  }

  Future<void> uploadAvatar(File file) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.uploadAvatar(file);
    ref.invalidateSelf();
  }
}
