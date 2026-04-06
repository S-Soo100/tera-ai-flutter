import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../guide/presentation/guide_providers.dart';

class DdayBanner extends ConsumerWidget {
  const DdayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(ddayProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        days >= 0
            ? 'dday_banner'.tr(namedArgs: {'days': days.toString()})
            : 'dday_expired'.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
