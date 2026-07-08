import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_cage/domain/cage_activity.dart';
import '../../my_cage/domain/terra_camera.dart';
import '../../my_cage/presentation/activity_format.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../../my_cage/presentation/widgets/hourly_activity_chart.dart';
import '../../my_pets/domain/pet.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import 'widgets/nightly_report_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: 'home_activity_tooltip'.tr(),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'profile_title'.tr(),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'home_welcome'.tr(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppStyles.spacing24),
            _LiveSection(pets: pets),
            const SizedBox(height: AppStyles.spacing24),
            const NightlyReportBadge(),
            _ActivitySection(),
          ],
        ),
      ),
    );
  }
}

// ── 내 개체 (라이브) ───────────────────────────────────────────────────────────

class _LiveSection extends StatelessWidget {
  const _LiveSection({required this.pets});

  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryPet = pets.isNotEmpty ? pets.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'home_live_section'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            _ConnectedBadge(connected: primaryPet != null),
          ],
        ),
        const SizedBox(height: AppStyles.spacing12),
        if (primaryPet == null)
          _EmptyLiveCard()
        else
          _LiveCard(pet: primaryPet),
      ],
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xFF2E7D32)
        : Theme.of(context).colorScheme.outline;
    final bg = connected
        ? const Color(0xFFE8F5E9)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        connected
            ? 'home_live_connected'.tr()
            : 'home_live_disconnected'.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/crecam'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppStyles.spacing16),
          child: Row(
            children: [
              _PetAvatarWithPlay(pet: pet),
              const SizedBox(width: AppStyles.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pet.name} ${pet.speciesName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.thermostat,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '24.5°C',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.water_drop_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('68%', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetAvatarWithPlay extends StatelessWidget {
  const _PetAvatarWithPlay({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = pet.photoPath != null && pet.photoPath!.isNotEmpty;
    final isNetwork = hasPhoto && pet.photoPath!.startsWith('http');
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasPhoto
                  ? (isNetwork
                      ? CachedNetworkImage(
                          imageUrl: pet.photoPath!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                          ),
                          errorWidget: (_, __, ___) => _fallback(context),
                        )
                      : Image.file(
                          File(pet.photoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(context),
                        ))
                  : _fallback(context),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Image.asset('assets/images/logo.png', width: 28, height: 28),
      ),
    );
  }
}

class _EmptyLiveCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppStyles.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: AppStyles.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home_live_empty_title'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'home_live_empty_subtitle'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 활동량 분석 요약 ───────────────────────────────────────────────────────────

/// 홈 대시보드 활동량 카드. 대표(활성=최근 모션) 카메라 1대의 실측 활동량을
/// 요약한다. 카메라가 없거나 조회 실패면 섹션 자체를 숨겨 가짜 수치를 안 띄운다.
class _ActivitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camAsync = ref.watch(representativeCameraProvider);
    return camAsync.when(
      loading: () => _card(
        context,
        const SkeletonLoading(width: double.infinity, height: 128),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (cam) {
        if (cam == null) return const SizedBox.shrink();
        return _card(context, _ActivityContent(camera: cam));
      },
    );
  }

  Widget _card(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home_activity_section'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppStyles.spacing12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

/// 대표 카메라의 '어제'(완결된 지난 하루, 07:00~07:00) 활동량 —
/// 총합 + 시간대별 그래프. 카드에 카메라 이름을 명시해 어느 카메라 데이터인지 밝힌다.
class _ActivityContent extends ConsumerWidget {
  const _ActivityContent({required this.camera});

  final TerraCamera camera;

  static const _range = ActivityRange.yesterday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final totalAsync = ref
        .watch(motionActivityProvider((cameraId: camera.id, range: _range)));
    final hourlyAsync = ref
        .watch(hourlyActivityProvider((cameraId: camera.id, range: _range)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.videocam_outlined,
                size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                camera.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_activity_total_label'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: primary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  totalAsync.when(
                    loading: () => const SkeletonLoading(width: 96, height: 30),
                    error: (_, __) => _totalText(theme, primary, '—'),
                    data: (seconds) => _totalText(
                        theme, primary, formatMotionDuration(seconds)),
                  ),
                ],
              ),
            ),
            Icon(Icons.monitor_heart_outlined, size: 28, color: primary),
          ],
        ),
        const SizedBox(height: 16),
        hourlyAsync.when(
          loading: () =>
              const SkeletonLoading(width: double.infinity, height: 100),
          error: (_, __) => const SizedBox(height: 100),
          data: (hourly) => HourlyActivityChart(
            hourlySeconds: hourly,
            dayStartHour: kCageDayStartHour,
            height: 80,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'home_activity_range'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalText(ThemeData theme, Color color, String text) {
    return Text(
      text,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
