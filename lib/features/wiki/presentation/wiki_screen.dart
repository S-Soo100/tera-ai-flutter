import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'wiki_providers.dart';

class WikiScreen extends ConsumerWidget {
  const WikiScreen({super.key});

  static const _speciesChips = [
    ('crested-gecko', '크레스티드 게코'),
    ('leopard-gecko', '레오파드 게코'),
    ('fat-tailed-gecko', '펫테일 게코'),
  ];

  static const _categories = [
    ('temperature', '🌡️ 온도·습도'),
    ('enclosure', '🏠 사육장'),
    ('diet', '🍽️ 먹이'),
    ('mistakes', '⚠️ 초보 실수'),
    ('morph-guide', '📖 모프 도감'),
    ('morph-calc', '🧬 모프 계산기'),
    ('compare', '📋 종 비교'),
    ('ai-chat', '🤖 AI에게 물어보기'),
  ];

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
      floatingActionButton: FloatingActionButton(
        heroTag: 'wiki_chat_fab',
        onPressed: () =>
            context.push('/chat/new?speciesId=$selectedSpecies'),
        tooltip: 'AI에게 물어보기',
        child: const Icon(Icons.chat),
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
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(selectedWikiSpeciesProvider.notifier).state = id;
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
                        style: Theme.of(context).textTheme.titleMedium,
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
                          _SummaryChip(label: '난이도', value: info.difficulty),
                          const SizedBox(width: 8),
                          _SummaryChip(label: '수명', value: info.lifespan),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _SummaryChip(label: '크기', value: info.adultSize),
                          const SizedBox(width: 8),
                          _SummaryChip(label: '성격', value: info.temperament),
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
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: _categories.map((cat) {
                  final (categoryId, label) = cat;
                  return _CategoryCard(
                    label: label,
                    onTap: () {
                      if (categoryId == 'compare') {
                        context.push('/wiki/compare');
                      } else if (categoryId == 'morph-guide') {
                        context.push('/wiki/$selectedSpecies/morph-guide');
                      } else if (categoryId == 'morph-calc') {
                        context.push('/wiki/$selectedSpecies/morph-calc');
                      } else if (categoryId == 'ai-chat') {
                        context.push(
                            '/chat/new?speciesId=$selectedSpecies');
                      } else {
                        context.push('/wiki/$selectedSpecies/$categoryId');
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

  const _SummaryChip({required this.label, required this.value});

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
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
  final VoidCallback onTap;

  const _CategoryCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
