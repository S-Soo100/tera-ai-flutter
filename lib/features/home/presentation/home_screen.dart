import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'home_providers.dart';
import '../../my_pets/data/pet_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesRepo = ref.watch(speciesRepositoryProvider);
    final petRepo = ref.watch(petRepositoryProvider);
    final pets = petRepo.getAllPets();
    final featuredSpecies = speciesRepo.featuredSpecies;
    final daysLeft =
        DateTime(2026, 6, 13).difference(DateTime.now()).inDays;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tera AI'),
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
            Text('사육 가이드', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...featuredSpecies.map((species) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(species.koreanName),
                  subtitle: Text(species.tags.join(' / ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/wiki'),
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
    return Card(
      color: colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/guide'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '자진신고 마감 D-$daysLeft',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2026년 6월 13일까지',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onPrimaryContainer),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.pets, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            const Text(
              '개체를 등록하고 맞춤 사육 가이드를 받아보세요',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/my-pets/add'),
              icon: const Icon(Icons.add),
              label: const Text('첫 개체 등록하기'),
            ),
          ],
        ),
      ),
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
        Text('내 개체 (${pets.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pets.length + 1,
            itemBuilder: (context, index) {
              // 마지막: 추가 카드
              if (index == pets.length) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 120,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.go('/my-pets/add'),
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
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 140,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go('/my-pets/${pet.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pet.sexIcon,
                                  style: theme.textTheme.titleMedium,
                                ),
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
                            const SizedBox(height: 8),
                            Text(
                              pet.speciesName,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            if (pet.adoptionDuration.isNotEmpty)
                              Text(
                                pet.adoptionDuration,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
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
