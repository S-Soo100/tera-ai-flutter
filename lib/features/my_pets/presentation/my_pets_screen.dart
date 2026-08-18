import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_segmented_control.dart';
import '../../../shared/widgets/glass_tab_header.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
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

    // A안 표면 규칙은 [GlassTabShell] 한 곳이 맡는다. 탭 전환·CRUD 로직은 불변.
    return GlassTabShell(
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
      // 하단은 플로팅 독 높이를 [glassDockListPadding]이 직접 소비한다.
      padding: glassDockListPadding(context,
          base: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16)),
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

/// 개체 카드 — B안 **보딩패스** 문법(2026-08-18).
///
/// ```
/// [사진]  이름 (크게)  [수컷]
///         종
/// ◖- - - - - - - - - - - - - - - - - -◗   ← 절취선
/// MORPH          AGE           WEIGHT
/// 릴리화이트     D+412         38.5g
/// [ 정보 수정 ]
/// ```
///
/// 데이터는 [petListProvider]의 [Pet] 그대로 — 탭은 상세(`/my-pets/:id`),
/// "정보 수정"은 편집 화면. 값이 없는 칸은 `--`(0·가짜 날짜로 위장하지 않는다).
/// AGE는 생년월이 있을 때 D+N, 없고 입양일만 있으면 라벨을 ADOPTED로 바꿔
/// 입양 경과일을 보여준다 — 두 날짜를 한 라벨 아래 섞지 않는다.
class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단: 사진 + 이름(크게) + 종 + 성별 배지. 탭 → 상세.
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => context.push('/my-pets/${pet.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppStyles.spacing16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PetThumbnail(pet: pet),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pet.name,
                                style: glass.figureMid,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SexBadge(sex: pet.sex),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pet.speciesName,
                          style: glass.tileStatus
                              .copyWith(color: glass.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 절취선 — 보딩패스 문법. 홈은 바닥색으로 파낸다.
          Row(
            children: [
              const _Notch(isLeft: true),
              Expanded(
                child: CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: _DashPainter(color: glass.border),
                ),
              ),
              const _Notch(isLeft: false),
            ],
          ),
          // 하단: 게이트/좌석 문법 3열 (MORPH | AGE | WEIGHT) + 정보 수정.
          Padding(
            padding: const EdgeInsets.all(AppStyles.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PassField(
                        label: 'my_pets_pass_morph'.tr(),
                        value: (pet.morph == null || pet.morph!.isEmpty)
                            ? 'home_value_none'.tr()
                            : pet.morph!,
                      ),
                    ),
                    Expanded(flex: 2, child: _ageField(pet)),
                    Expanded(
                      flex: 2,
                      child: _PassField(
                        label: 'my_pets_pass_weight'.tr(),
                        value: pet.weight == null
                            ? 'home_value_none'.tr()
                            : 'my_pets_pass_weight_value'
                                .tr(args: [pet.weight!.toStringAsFixed(1)]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppStyles.spacing12),
                OutlinedButton(
                  onPressed: () => context.push('/my-pets/${pet.id}/edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // 솔리드 표면 위라 테마 outline은 묻힌다 — 팔레트 테두리
                    // 토큰으로 맞춘다.
                    side: BorderSide(color: glass.border),
                    foregroundColor: glass.textPrimary,
                  ),
                  child: Text('my_pets_edit_info'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// AGE(생년월 기준 D+N) → 없으면 ADOPTED(입양일 기준 D+N) → 둘 다 없으면 `--`.
  static Widget _ageField(Pet pet) {
    final birth = pet.birthDate;
    final adopted = pet.adoptionDate;
    if (birth != null) {
      return _PassField(
        label: 'my_pets_pass_age'.tr(),
        value: 'my_pets_pass_days'.tr(namedArgs: {'n': '${_daysSince(birth)}'}),
        accent: true,
      );
    }
    if (adopted != null) {
      return _PassField(
        label: 'my_pets_pass_adopted'.tr(),
        value:
            'my_pets_pass_days'.tr(namedArgs: {'n': '${_daysSince(adopted)}'}),
        accent: true,
      );
    }
    return _PassField(
        label: 'my_pets_pass_age'.tr(), value: 'home_value_none'.tr());
  }

  /// **달력 날짜 차이**다. 시각까지 든 DateTime을 그대로 빼면 자정 전후로
  /// 하루가 어긋난다(저녁에 태어난 개체가 다음날 아침에도 D+0).
  static int _daysSince(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final n = today.difference(day).inDays;
    return n < 0 ? 0 : n;
  }
}

class _PassField extends StatelessWidget {
  const _PassField({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;

  /// 앰버 강조 — 보딩패스의 게이트 번호처럼 눈이 먼저 가는 칸(AGE).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: glass.labelCaps, maxLines: 1),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: glass.tileTitle.copyWith(
            fontWeight: FontWeight.w700,
            color: accent ? glass.signalWarn : glass.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 절취선 좌우 반원 홈 — 바닥색으로 파낸다.
class _Notch extends StatelessWidget {
  const _Notch({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 16,
      decoration: BoxDecoration(
        color: context.glass.wallpaper,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? Radius.zero : const Radius.circular(16),
          right: isLeft ? const Radius.circular(16) : Radius.zero,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
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
        width: 64,
        height: 64,
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
    // **배지가 화면에서 제일 밝은 조각**이 된다(실기기 확인) — 팔레트가
    // 밝기별로 쌍을 만든다.
    final t = context.glass.badgeTone(
      isMale ? AppTheme.subBlue : AppTheme.subRed,
      lightBg: isMale ? AppTheme.subBlueBg : AppTheme.subRedBg,
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
    // Material(transparency)은 리플이 앉을 면 — 없으면 잉크가 불투명
    // 월페이퍼 뒤에 그려져 눌러도 반응이 안 보인다.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/my-pets/add'),
        child: Container(
          padding: const EdgeInsets.all(AppStyles.spacing24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.glass.border,
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.add,
                size: 32,
                color: context.glass.textSecondary,
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
                  color: context.glass.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
