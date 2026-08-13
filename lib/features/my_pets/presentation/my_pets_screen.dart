import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_segmented_control.dart';
import '../../../shared/widgets/glass_tab_header.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/wallpaper_background.dart';
import '../../my_cage/presentation/nightly_report_view.dart';
import '../../profile/presentation/profile_providers.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';

enum _MyPetsTab { list, report }

class MyPetsScreen extends ConsumerStatefulWidget {
  const MyPetsScreen({super.key});

  @override
  ConsumerState<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends ConsumerState<MyPetsScreen> {
  _MyPetsTab _selected = _MyPetsTab.list;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petListProvider);
    final intent = ref.watch(myPetsTabProvider);
    if (intent == 1 && _selected != _MyPetsTab.report) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selected = _MyPetsTab.report);
          ref.read(myPetsTabProvider.notifier).state = 0;
        }
      });
    }

    final profile = ref.watch(profileNotifierProvider).valueOrNull;

    // A안 표면 규칙은 홈([HomeScreen])과 같다 — 월페이퍼 바닥 +
    // SafeArea(bottom: false). 다크 팔레트는 앱 전역이 보장한다(`app.dart`).
    // 탭 전환·CRUD 로직은 불변.
    return Scaffold(
      backgroundColor: AppTheme.glassWallpaperTop,
      body: Stack(
        children: [
          const Positioned.fill(child: WallpaperBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 홈·통계와 같은 헤더 문법. 탭마다 제목 스타일이 다르면
                // 탭을 옮길 때마다 다른 앱처럼 보인다.
                GlassTabHeader(
                  title: 'my_pets_title'.tr(),
                  actions: [
                    HeaderAction(
                      icon: Icons.add,
                      tooltip: 'my_pets_add'.tr(),
                      onPressed: () => context.push('/my-pets/add'),
                    ),
                    AccountAvatar(
                      tooltip: 'home_account'.tr(),
                      imageUrl: profile?.avatarUrl,
                      displayName: profile?.displayName,
                      onPressed: () => context.push('/profile'),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacing16),
                  child: _TabChips(
                    selected: _selected,
                    onChanged: (t) => setState(() => _selected = t),
                  ),
                ),
                const SizedBox(height: AppStyles.spacing16),
                Expanded(child: _tabContent(_selected, pets)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabContent(_MyPetsTab selected, List<Pet> pets) {
    switch (selected) {
      case _MyPetsTab.list:
        return _PetListView(pets: pets);
      case _MyPetsTab.report:
        return const NightlyReportView();
    }
  }
}

// ── 상단 뷰 전환 ──────────────────────────────────────────────────────────────

/// `[개체 목록] [리포트]`.
///
/// 통계 탭의 기간 선택·홈 서브탭과 **같은 유리 세그먼트**를 쓴다 — 유리
/// 트랙 안에서 선택 탭만 불투명 흰 알약(A안 문법). 선택 로직은 불변.
class _TabChips extends StatelessWidget {
  const _TabChips({required this.selected, required this.onChanged});

  final _MyPetsTab selected;
  final ValueChanged<_MyPetsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSegmentedControl<_MyPetsTab>(
      segments: [
        GlassSegment(value: _MyPetsTab.list, label: 'my_pets_tab_list'.tr()),
        GlassSegment(
            value: _MyPetsTab.report, label: 'my_pets_tab_report'.tr()),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

// ── 개체 목록 뷰 ──────────────────────────────────────────────────────────────

class _PetListView extends StatelessWidget {
  const _PetListView({required this.pets});
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // 헤더와 같은 16pt. 예전엔 20이라 제목보다 4pt 안쪽으로 들어가 있었다.
      // 하단은 플로팅 독 높이(MediaQuery.padding.bottom)를 직접 소비한다 —
      // padding을 명시한 ListView는 자동 인셋이 꺼진다.
      padding: EdgeInsets.fromLTRB(
          AppStyles.spacing16,
          0,
          AppStyles.spacing16,
          AppStyles.spacing24 + MediaQuery.paddingOf(context).bottom),
      children: [
        ...pets.map((pet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PetCard(pet: pet),
            )),
        _AddPetCard(),
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A안 유리 카드. 안의 구성(썸네일·이름·성별 배지·수정 버튼)은 불변 —
    // 감싸는 표면만 유리다.
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/my-pets/${pet.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PetThumbnail(pet: pet),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pet.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SexBadge(sex: pet.sex),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _subtitle(pet),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (pet.adoptionDate != null)
                          Text(
                            'my_pets_adoption_date'.tr(
                              namedArgs: {
                                'date': _formatDate(pet.adoptionDate!),
                              },
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/my-pets/${pet.id}/edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // 유리 위라 테마 다크 outline(#333)은 묻힌다 — 유리 테두리
                  // 토큰으로 맞춘다.
                  side: const BorderSide(color: AppTheme.glassBorder),
                  foregroundColor: AppTheme.glassTextPrimary,
                ),
                child: Text('my_pets_edit_info'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Pet pet) {
    final parts = <String>[];
    if (pet.morph != null && pet.morph!.isNotEmpty) parts.add(pet.morph!);
    if (pet.weight != null) {
      parts.add('${pet.weight!.toStringAsFixed(0)}g');
    }
    if (parts.isEmpty) return pet.speciesName;
    return parts.join(' | ');
  }

  String _formatDate(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

class _PetThumbnail extends StatelessWidget {
  const _PetThumbnail({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = pet.photoPath != null && pet.photoPath!.isNotEmpty;
    final isNetwork = hasPhoto && pet.photoPath!.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        height: 80,
        child: hasPhoto
            ? (isNetwork
                ? CachedNetworkImage(
                    imageUrl: pet.photoPath!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _fallback(context),
                    errorWidget: (_, __, ___) => _fallback(context),
                  )
                : Image.file(
                    File(pet.photoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(context),
                  ))
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Image.asset('assets/images/logo.png', width: 36, height: 36),
      ),
    );
  }
}

class _SexBadge extends StatelessWidget {
  const _SexBadge({required this.sex});
  final String sex;

  @override
  Widget build(BuildContext context) {
    if (sex == 'unknown') return const SizedBox.shrink();
    final isMale = sex == 'male';
    // 예전엔 `isMale ? 분홍 : 분홍`이라 **암수가 같은 색**이었다 — 배지가
    // 구분을 못 하고 있었다. 팔레트에 없는 하드코딩 색이기도 했다.
    //
    // `*Bg`를 직접 쓰지 않는다. 그 파스텔은 라이트 전용이라 다크에서
    // **배지가 화면에서 제일 밝은 조각**이 된다(실기기 확인).
    final t = AppTheme.subBadgeTone(
      isMale ? AppTheme.subBlue : AppTheme.subRed,
      isMale ? AppTheme.subBlueBg : AppTheme.subRedBg,
      Theme.of(context).brightness,
    );
    final color = t.fg;
    final bg = t.bg;
    final label = isMale ? 'pet_sex_male'.tr() : 'pet_sex_female'.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddPetCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 채운 유리 카드가 아니라 **빈 틀**이다 — 개체 카드와 같은 모양이면
    // "내용이 있는데 비었다"로 읽힌다. 테두리만 유리 토큰으로 맞춘다.
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/my-pets/add'),
      child: Container(
        padding: const EdgeInsets.all(AppStyles.spacing24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.glassBorder,
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.add,
              size: 32,
              color: AppTheme.glassTextSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'my_pets_add_new_title'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'my_pets_add_new_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.glassTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
