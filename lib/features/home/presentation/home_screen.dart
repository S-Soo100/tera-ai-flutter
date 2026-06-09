import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../my_pets/domain/pet.dart';
import '../../my_pets/presentation/my_pets_providers.dart';

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

class _ActivitySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          child: const _ActivityContent(),
        ),
      ],
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const greenColor = Color(0xFF2E7D32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_activity_total_label'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: greenColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'home_activity_total_value'.tr(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: greenColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.monitor_heart_outlined,
              size: 28,
              color: greenColor,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 80,
          child: _ActivityBarChart(),
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
}

class _ActivityBarChart extends StatelessWidget {
  const _ActivityBarChart();

  // 더미 데이터 (P0). P2에서 실제 활동량 데이터로 교체.
  static const _values = [0.4, 0.55, 0.35, 0.45, 0.7, 0.65, 0.9, 0.3];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_values.length, (i) {
            final h = math.max(8.0, _values[i] * maxHeight);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
