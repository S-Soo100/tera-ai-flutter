import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String _experience = 'beginner';
  bool _isUploading = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    _nameController.text = profile.displayName ?? '';
    _experience = profile.experience ?? 'beginner';
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(profileNotifierProvider.notifier).uploadAvatar(File(image.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_avatar_updated'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileNotifierProvider.notifier).updateProfile(
            displayName: _nameController.text.trim(),
            experience: _experience,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_saved'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('profile_title'.tr())),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          _initFromProfile(profile);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 아바타
                GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        backgroundImage: profile?.avatarUrl != null
                            ? NetworkImage(profile!.avatarUrl!)
                            : null,
                        child: profile?.avatarUrl == null
                            ? Icon(Icons.person, size: 48, color: colorScheme.onSurfaceVariant)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.primary,
                          child: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Icon(Icons.camera_alt, size: 18, color: colorScheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 닉네임
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'profile_display_name'.tr(),
                    prefixIcon: const Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // 경험 레벨
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('profile_experience'.tr(), style: theme.textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'beginner', label: Text('profile_exp_beginner'.tr())),
                    ButtonSegment(value: 'intermediate', label: Text('profile_exp_intermediate'.tr())),
                    ButtonSegment(value: 'expert', label: Text('profile_exp_expert'.tr())),
                  ],
                  selected: {_experience},
                  onSelectionChanged: (v) => setState(() => _experience = v.first),
                ),
                const SizedBox(height: 24),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('profile_save'.tr()),
                  ),
                ),
                const SizedBox(height: 32),

                const Divider(),
                const SizedBox(height: 8),

                // 로그아웃
                ListTile(
                  leading: Icon(Icons.logout, color: colorScheme.error),
                  title: Text('auth_logout'.tr(), style: TextStyle(color: colorScheme.error)),
                  onTap: _logout,
                ),

                // 앱 버전
                ListTile(
                  leading: Icon(Icons.info_outlined, color: colorScheme.onSurfaceVariant),
                  title: Text('profile_app_version'.tr()),
                  subtitle: const Text('v1.0.0'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
