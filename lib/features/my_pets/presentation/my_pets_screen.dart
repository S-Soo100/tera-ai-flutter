import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/screen_header.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 홈·통계와 같은 헤더를 쓴다. 탭마다 제목 스타일이 다르면
            // 탭을 옮길 때마다 다른 앱처럼 보인다.
            ScreenHeader(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
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
/// 통계 탭의 기간 선택과 **같은 컨트롤**을 쓴다. 예전엔 초록 알약 칩이었는데,
/// 그 초록은 폐기된 옛 브랜드색(`AppTheme.success`)이라 이제는 "정상" 의미색과
/// 충돌했다 — 상태가 아니라 선택을 뜻하는 자리다.
class _TabChips extends StatelessWidget {
  const _TabChips({required this.selected, required this.onChanged});

  final _MyPetsTab selected;
  final ValueChanged<_MyPetsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_MyPetsTab>(
      segments: [
        ButtonSegment(
            value: _MyPetsTab.list, label: Text('my_pets_tab_list'.tr())),
        ButtonSegment(
            value: _MyPetsTab.report, label: Text('my_pets_tab_report'.tr())),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
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
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16, 0, AppStyles.spacing16, AppStyles.spacing24),
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
    return Container(
      padding: const EdgeInsets.all(AppStyles.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: Text('my_pets_edit_info'.tr()),
            ),
          ),
        ],
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
    final color = isMale ? AppTheme.subBlue : AppTheme.subRed;
    final bg = isMale ? AppTheme.subBlueBg : AppTheme.subRedBg;
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/my-pets/add'),
      child: Container(
        padding: const EdgeInsets.all(AppStyles.spacing24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
