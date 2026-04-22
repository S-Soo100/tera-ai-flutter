import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'wiki_providers.dart';

class WikiScreen extends ConsumerWidget {
  const WikiScreen({super.key});

  static const _speciesChips = [
    ('crested-gecko', '크레스티드 게코'),
    ('leopard-gecko', '레오파드 게코'),
    ('fat-tailed-gecko', '펫테일 게코'),
  ];

  static final _categories = <({String id, String label, IconData icon, bool highlighted})>[
    (id: 'temperature', label: '온도·습도', icon: Icons.thermostat_rounded, highlighted: false),
    (id: 'diet', label: '먹이', icon: Icons.restaurant_rounded, highlighted: false),
    (id: 'enclosure', label: '사육장', icon: Icons.house_rounded, highlighted: false),
    (id: 'mistakes', label: '초보 실수', icon: Icons.warning_amber_rounded, highlighted: false),
    (id: 'morph-guide', label: '모프 도감', icon: Icons.auto_stories_rounded, highlighted: false),
    (id: 'morph-calc', label: '모프 계산기', icon: Icons.biotech_rounded, highlighted: false),
    (id: 'compare', label: '종 비교', icon: Icons.compare_arrows_rounded, highlighted: false),
    (id: 'ai-chat', label: 'AI에게 물어보기', icon: Icons.smart_toy_rounded, highlighted: false),
  ];

  String _difficultyLabel(String raw) {
    switch (raw) {
      case 'beginner':
        return '쉬움';
      case 'intermediate':
        return '보통';
      case 'advanced':
        return '어려움';
      default:
        return raw;
    }
  }

  String _shortTemperament(String value) {
    final dotIndex = value.indexOf('.');
    if (dotIndex == -1) return value;
    return value.substring(0, dotIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSpecies = ref.watch(selectedWikiSpeciesProvider);
    final careInfoAsync = ref.watch(careInfoProvider(selectedSpecies));

    return Scaffold(
      appBar: AppBar(
        title: const Text('사육 위키'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '대화 기록',
            onPressed: () => context.push('/chat'),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          heroTag: 'wiki_chat_fab',
          onPressed: () =>
              context.push('/chat/new?speciesId=$selectedSpecies'),
          tooltip: 'AI에게 물어보기',
          child: const Icon(Icons.chat),
        ),
      ),
      body: Column(
        children: [
          // Species selection chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _speciesChips.map((chip) {
                  final (id, label) = chip;
                  final isSelected = selectedSpecies == id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        label,
                        style: isSelected
                            ? const TextStyle(fontWeight: FontWeight.bold)
                            : null,
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(selectedWikiSpeciesProvider.notifier).state =
                            id;
                      },
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Summary card
          careInfoAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonCard(lineCount: 4),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('정보를 불러올 수 없습니다: $e'),
                ),
              ),
            ),
            data: (info) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.speciesNameKo,
                        style: AppStyles.subsectionTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.scientificName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _SummaryChip(
                            label: '난이도',
                            value: _difficultyLabel(info.difficulty),
                            icon: Icons.star_rounded,
                          ),
                          const SizedBox(width: 8),
                          _SummaryChip(
                            label: '수명',
                            value: info.lifespan,
                            icon: Icons.hourglass_empty_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _SummaryChip(
                            label: '크기',
                            value: info.adultSize,
                            icon: Icons.straighten_rounded,
                          ),
                          const SizedBox(width: 8),
                          _SummaryChip(
                            label: '성격',
                            value: _shortTemperament(info.temperament),
                            icon: Icons.pets_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Category grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: _categories.map((cat) {
                  return _CategoryCard(
                    label: cat.label,
                    icon: cat.icon,
                    highlighted: cat.highlighted,
                    onTap: () {
                      if (cat.id == 'compare') {
                        context.push('/wiki/compare');
                      } else if (cat.id == 'morph-guide') {
                        context.push('/wiki/$selectedSpecies/morph-guide');
                      } else if (cat.id == 'morph-calc') {
                        context.push('/wiki/$selectedSpecies/morph-calc');
                      } else if (cat.id == 'ai-chat') {
                        context.push(
                            '/chat/new?speciesId=$selectedSpecies');
                      } else {
                        context.push('/wiki/$selectedSpecies/${cat.id}');
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = highlighted
        ? Theme.of(context).colorScheme.primaryContainer
        : null;
    final iconColor = highlighted
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: bgColor,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
