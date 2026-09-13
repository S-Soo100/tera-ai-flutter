import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/fan_timer_duration.dart';

final fanDurationSelectionProvider =
    StateProvider.autoDispose<FanTimerDuration?>((ref) => FanTimerDuration.m30);
final _submittedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Options only change selection. Only Start returns an executable choice.
class FanDurationSheet extends ConsumerWidget {
  const FanDurationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(fanDurationSelectionProvider);
    final submitted = ref.watch(_submittedProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('home_fan_pick_title'.tr(),
                style: AppStyles.subsectionTitle(context)),
            const SizedBox(height: AppStyles.spacing16),
            Wrap(
              spacing: AppStyles.spacing8,
              runSpacing: AppStyles.spacing8,
              children: [
                for (final duration in FanTimerDuration.values)
                  ChoiceChip(
                    key: Key('fan_timer_${duration.minutes}'),
                    label: Text(duration.labelKey.tr()),
                    selected: selected == duration,
                    onSelected: submitted
                        ? null
                        : (_) => ref
                            .read(fanDurationSelectionProvider.notifier)
                            .state = duration,
                  ),
                ChoiceChip(
                  key: const Key('fan_steady_on'),
                  label: Text('home_fan_steady_on'.tr()),
                  selected: selected == null,
                  onSelected: submitted
                      ? null
                      : (_) => ref
                          .read(fanDurationSelectionProvider.notifier)
                          .state = null,
                ),
              ],
            ),
            const SizedBox(height: AppStyles.spacing16),
            FilledButton(
              key: const Key('fan_start'),
              onPressed: submitted
                  ? null
                  : () {
                      if (ref.read(_submittedProvider)) return;
                      ref.read(_submittedProvider.notifier).state = true;
                      Navigator.of(context).pop((selected,));
                    },
              child: Text('home_fan_start'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
