import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import 'home_providers.dart';

class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final allCategories = ['전체', ...AppConstants.categories];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: allCategories.map((category) {
          final isSelected = selectedCategory == category;
          final label = _getCategoryLabel(category);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                ref.read(selectedCategoryProvider.notifier).state = category;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case '전체':
        return 'category_all'.tr();
      case '도마뱀':
        return 'category_lizard'.tr();
      case '뱀':
        return 'category_snake'.tr();
      case '거북':
        return 'category_turtle'.tr();
      case '양서류':
        return 'category_amphibian'.tr();
      default:
        return category;
    }
  }
}
