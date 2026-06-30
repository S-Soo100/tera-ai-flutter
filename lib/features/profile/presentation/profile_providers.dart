import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

/// 앱 버전 (pubspec → 런타임). 'v0.1.1' 형태로 표시.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    // 인증 상태를 watch → 로그인/로그아웃/계정 전환 시 자동 재build (stale 방지)
    ref.watch(currentUserProvider);
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
