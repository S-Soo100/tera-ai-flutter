import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_providers.dart';

class PopularSearches extends ConsumerWidget {
  const PopularSearches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularSearches = ref.watch(popularSearchesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'popular_searches'.tr(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: popularSearches.map((keyword) {
              return ActionChip(
                label: Text(keyword),
                onPressed: () {
                  ref.read(searchQueryProvider.notifier).state = keyword;
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
