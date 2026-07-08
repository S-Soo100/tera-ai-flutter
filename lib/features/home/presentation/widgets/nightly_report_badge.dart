import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../my_cage/presentation/my_cage_providers.dart';
import '../../../my_pets/presentation/my_pets_providers.dart';

/// "어젯밤 리포트" 홈 배지. 밤 활동이 전무하면 숨김, 있으면 하이라이트 건수(0이면
/// "조용한 밤")를 보여주고 탭 시 마이 크레 리포트 탭으로 이동.
class NightlyReportBadge extends ConsumerWidget {
  const NightlyReportBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nightlyReportProvider);
    final report = async.valueOrNull;
    if (report == null) return const SizedBox.shrink();
    if (report.highlights.isEmpty && report.activitySeconds == 0) {
      return const SizedBox.shrink();
    }
    final n = report.highlights.length;
    final sub = n > 0
        ? 'nightly_report_badge_sub'.tr(namedArgs: {'n': '$n'})
        : 'nightly_report_badge_quiet'.tr();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref.read(myPetsTabProvider.notifier).state = 1;
            context.go('/my-pets');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text('🦎', style: theme.textTheme.titleLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('nightly_report_title'.tr(),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        sub,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
