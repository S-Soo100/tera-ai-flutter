import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/viva_check_row.dart';
import '../../../shared/widgets/viva_text_field.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';
import 'widgets/my_page_widgets.dart';

/// 커뮤니티 프로필(Figma Commu_Profile 1142:9369). 흰 배경. 아바타 160 +
/// 사진 버튼 44, 닉네임(10자 카운터), 사육 경험 3택(60h, 선택 `#192553`
/// + check), "커뮤니티에 내 사육 경험 비공개", 플로팅 저장(y696, 변경 있을 때만).
class CommunityProfileScreen extends ConsumerStatefulWidget {
  const CommunityProfileScreen({super.key});

  static const nicknameKey = Key('commu_profile_nickname');
  static const saveKey = Key('commu_profile_save');
  static const hideKey = Key('commu_profile_hide');
  static const photoKey = Key('commu_profile_photo');
  static Key experienceKey(String value) => Key('commu_profile_exp_$value');

  @override
  ConsumerState<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
}

class _CommunityProfileScreenState
    extends ConsumerState<CommunityProfileScreen> {
  final _name = TextEditingController();
  String? _experience;
  bool _hidden = false;
  String? _initializedForId;
  String? _nameError;
  bool _saving = false;
  bool _uploading = false;

  static const _experiences = ['beginner', 'intermediate', 'expert'];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _nameError = null));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _init(UserProfile? p) {
    if (p == null || p.id == _initializedForId) return;
    _initializedForId = p.id;
    _name.text = p.displayName ?? '';
    _experience = p.experience;
    _hidden = p.experienceHidden;
  }

  bool _dirty(UserProfile? p) =>
      _name.text.trim() != (p?.displayName ?? '') ||
      _experience != p?.experience ||
      _hidden != (p?.experienceHidden ?? false);

  Future<void> _save(UserProfile? p) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'commu_profile_nickname_required'.tr());
      return;
    }
    if (name.characters.length > 10) {
      setState(() => _nameError = 'commu_profile_nickname_too_long'.tr());
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileNotifierProvider.notifier).updateProfile(
            displayName: name,
            experience: _experience,
            // 컬럼이 없는 프로젝트에 보내면 400 — 지원될 때만.
            experienceHidden:
                (p?.experienceHiddenSupported ?? false) ? _hidden : null,
          );
      if (!mounted) return;
      _initializedForId = null;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('commu_profile_saved'.tr())));
      Navigator.of(context).maybePop();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _nameError = e.code == '23505'
          ? 'commu_profile_nickname_duplicate'.tr()
          : e.message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (image == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref
          .read(profileNotifierProvider.notifier)
          .uploadAvatar(File(image.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final profileAsync = ref.watch(profileNotifierProvider);
    final profile = profileAsync.valueOrNull;
    _init(profile);
    final canSave = !_saving && profileAsync.hasValue && _dirty(profile);
    return MyPageScaffold(
      title: 'commu_profile_title'.tr(),
      white: true,
      floating: MyPageCta(
          key: CommunityProfileScreen.saveKey,
          label: 'commu_profile_save'.tr(),
          onPressed: canSave ? () => _save(profile) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
            child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(children: [
                  _uploading
                      ? const SkeletonLoading(
                          width: 160, height: 160, borderRadius: 80)
                      : MyPageAvatar(size: 160, imageUrl: profile?.avatarUrl),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                          key: CommunityProfileScreen.photoKey,
                          color: glass.surfaceTint,
                          shape: const CircleBorder(),
                          child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _uploading ? null : _pickPhoto,
                              child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                      child: FigmaIcon.tinted(
                                          'redesign_v2/add_photo_alternate',
                                          size: 24,
                                          color: glass.textSecondary)))))),
                ]))),
        const SizedBox(height: 24),
        VivaTextField(
            fieldKey: CommunityProfileScreen.nicknameKey,
            label: 'commu_profile_nickname'.tr(),
            controller: _name,
            hintText: 'commu_profile_nickname_hint'.tr(),
            maxLength: 10,
            errorText: _nameError,
            textInputAction: TextInputAction.done),
        Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text('commu_profile_experience'.tr(),
                style: managementStyle(context, color: glass.textTertiary))),
        _ExperienceToggle(
            value: _experience,
            onChanged: (v) => setState(() => _experience = v)),
        const SizedBox(height: 12),
        Padding(
            padding: const EdgeInsets.only(left: 8),
            child: VivaCheckRow(
                key: CommunityProfileScreen.hideKey,
                label: 'commu_profile_hide_experience'.tr(),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v))),
      ]),
    );
  }
}

/// 3택 토글 369×60 r12: 칸 `#F4F4F4` 선 `#E3E3E3`, 제목 16/500 + 설명 14/500,
/// 선택 칸 `#192553` + check 24 + 흰 글자.
class _ExperienceToggle extends StatelessWidget {
  const _ExperienceToggle({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            height: 60,
            child: Row(children: [
              for (final (i, e) in
                  _CommunityProfileScreenState._experiences.indexed)
                Expanded(
                    child: Material(
                        key: CommunityProfileScreen.experienceKey(e),
                        color: value == e
                            ? AppTheme.brandNavy
                            : glass.surfaceTint,
                        shape: value == e
                            ? null
                            : Border(
                                top: BorderSide(color: glass.border),
                                bottom: BorderSide(color: glass.border),
                                left: i == 0
                                    ? BorderSide(color: glass.border)
                                    : BorderSide.none,
                                right: BorderSide(color: glass.border)),
                        child: InkWell(
                            onTap: () => onChanged(e),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (value == e) ...[
                                    FigmaIcon.tinted('redesign_v2/check',
                                        size: 24,
                                        color: ManagementColors
                                            .buttonForeground(context)),
                                    const SizedBox(width: 4),
                                  ],
                                  Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(experienceLabelKey(e)!.tr(),
                                            style: managementStyle(context,
                                                color: value == e
                                                    ? ManagementColors
                                                        .buttonForeground(
                                                            context)
                                                    : glass.textSecondary)),
                                        const SizedBox(height: 4),
                                        Text(experienceDescKey(e)!.tr(),
                                            style: managementStyle(context,
                                                size: 14,
                                                color: value == e
                                                    ? ManagementColors
                                                        .buttonForeground(
                                                            context)
                                                    : glass.textTertiary)),
                                      ]),
                                ])))),
            ])));
  }
}
