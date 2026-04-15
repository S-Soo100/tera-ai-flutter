import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/app_tag.dart';
import '../../../shared/widgets/section_header.dart';
import 'home_providers.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../../wiki/presentation/wiki_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesRepo = ref.watch(speciesRepositoryProvider);
    final pets = ref.watch(petListProvider);
    final featuredSpecies = speciesRepo.featuredSpecies;
    final daysLeft = AppConstants.daysUntilDeadline;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tera AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outlined),
            tooltip: 'profile_title'.tr(),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- D-day 배너 ---
            _DdayBanner(daysLeft: daysLeft, colorScheme: colorScheme),
            const SizedBox(height: 24),

            // --- 내 개체 섹션 ---
            if (pets.isEmpty)
              _EmptyPetsSection(colorScheme: colorScheme)
            else
              _PetsSection(pets: pets),
            const SizedBox(height: 24),

            // --- 사육 가이드 섹션 ---
            const SectionHeader(title: '사육 가이드'),
            ...featuredSpecies.map((species) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Image.asset(
                    'assets/images/logo.png',
                    width: 40,
                    height: 40,
                  ),
                  title: Text(species.koreanName),
                  subtitle: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: species.tags
                        .map((tag) => AppTag(label: tag))
                        .toList(),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(selectedWikiSpeciesProvider.notifier).state =
                        species.id;
                    context.go('/wiki');
                  },
                ),
              );
            }),
            const SizedBox(height: 24),

            // --- 백색목록 검색 ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.search),
                title: const Text('우리 집 도마뱀, 합법일까?'),
                subtitle: const Text('백색목록 검색'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DdayBanner extends StatelessWidget {
  final int daysLeft;
  final ColorScheme colorScheme;

  const _DdayBanner({required this.daysLeft, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isExpired = daysLeft < 0;
    final displayText =
        isExpired ? '자진신고 기한이 지났습니다' : '자진신고 마감 D-$daysLeft';

    return Card(
      color: isExpired
          ? colorScheme.errorContainer
          : colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/guide'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 20,
                  color: isExpired
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isExpired
                                    ? colorScheme.onErrorContainer
                                    : colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2026년 6월 13일까지',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: (isExpired
                                        ? colorScheme.onErrorContainer
                                        : colorScheme.onPrimaryContainer)
                                    .withValues(alpha: 0.7),
                              ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isExpired
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPetsSection extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyPetsSection({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('내 개체', style: AppStyles.sectionTitle(context)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 56, height: 56),
                const SizedBox(height: 12),
                const Text(
                  '개체를 등록하고 맞춤 사육 가이드를 받아보세요',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/my-pets/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('첫 개체 등록하기'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PetsSection extends StatelessWidget {
  final List pets;

  const _PetsSection({required this.pets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 개체 (${pets.length})',
          style: AppStyles.sectionTitle(context),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pets.length + 1,
            itemBuilder: (context, index) {
              if (index == pets.length) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 120,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/my-pets/add'),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_circle_outline, size: 32),
                              SizedBox(height: 8),
                              Text('추가'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final pet = pets[index];
              final hasPhoto =
                  pet.photoPath != null && pet.photoPath!.isNotEmpty;
              final isNetwork =
                  hasPhoto && pet.photoPath!.startsWith('http');

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 150,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go('/my-pets/${pet.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 사진 영역
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: SizedBox(
                              height: 60,
                              width: double.infinity,
                              child: hasPhoto
                                  ? (isNetwork
                                      ? CachedNetworkImage(
                                          imageUrl: pet.photoPath!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: theme.colorScheme
                                                .surfaceContainerHigh,
                                          ),
                                          errorWidget:
                                              (context, url, error) =>
                                                  Container(
                                            color: theme.colorScheme
                                                .surfaceContainerHigh,
                                          ),
                                        )
                                      : Image.file(
                                          File(pet.photoPath!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            color: theme.colorScheme
                                                .surfaceContainerHigh,
                                          ),
                                        ))
                                  : Container(
                                      color: theme.colorScheme
                                          .surfaceContainerHigh,
                                      child: Center(
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          width: 28,
                                          height: 28,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          // 정보 영역
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(pet.sexIcon,
                                          style:
                                              theme.textTheme.titleSmall),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          pet.name,
                                          style: theme.textTheme.titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pet.speciesName,
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  if (pet.adoptionDuration.isNotEmpty)
                                    Text(
                                      pet.adoptionDuration,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
