import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/presentation/home_providers.dart';
import '../../home/data/species_repository.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final repo = ref.watch(speciesRepositoryProvider);
    final results = query.isEmpty ? <dynamic>[] : repo.search(query);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '종 이름, 학명, 영어명으로 검색하세요',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            ref.read(_searchQueryProvider.notifier).state = value;
          },
        ),
      ),
      body: query.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    '종 이름, 학명, 영어명으로 검색하세요',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : results.isEmpty
              ? Center(
                  child: Text(
                    '검색 결과가 없습니다',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final species = results[index];
                    final featured = repo.isFeatured(species.id);

                    return ListTile(
                      title: Text(species.koreanName),
                      subtitle: Text(species.scientificName),
                      leading: Chip(
                        label: Text(
                          species.category,
                          style: theme.textTheme.labelSmall,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      trailing: featured
                          ? ActionChip(
                              label: const Text('상세 정보'),
                              onPressed: () => context.go('/wiki'),
                              avatar: const Icon(Icons.menu_book, size: 16),
                            )
                          : Chip(
                              label: const Text('합법'),
                              backgroundColor:
                                  colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                              ),
                              side: BorderSide.none,
                            ),
                    );
                  },
                ),
    );
  }
}
